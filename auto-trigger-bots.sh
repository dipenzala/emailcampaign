#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ⚡ AUTO-TRIGGER 3 BOTS ON LAUNCH"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. SINGLE WORKFLOW WITH 3 PARALLEL JOBS
# ═══════════════════════════════════════════
echo "🤖 [1/6] Creating workflow with 3 parallel jobs..."

mkdir -p .github/workflows

# Remove old broken ones
rm -f .github/workflows/bot.yml 2>/dev/null
rm -f .github/workflows/bot-*.yml 2>/dev/null
rm -f .github/workflows/email-bot*.yml 2>/dev/null

cat > .github/workflows/bots.yml <<'EOF'
name: 🤖 Email Bots (3 Parallel)

on:
  # Schedule — every 5 min
  schedule:
    - cron: '*/5 * * * *'

  # Manual trigger
  workflow_dispatch:
    inputs:
      batch_size:
        description: 'Batch size per bot (10-40)'
        required: false
        default: '20'
      mode:
        description: 'run | once'
        required: false
        default: 'run'

  # API trigger from Vercel (repository_dispatch)
  repository_dispatch:
    types: [start-campaign]

jobs:
  send:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    strategy:
      fail-fast: false
      matrix:
        bot: [bot1, bot2, bot3]
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          npm install --ignore-scripts --no-audit --no-fund
          npx prisma generate
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}

      - name: Run ${{ matrix.bot }}
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          REDIS_URL: ${{ secrets.REDIS_URL }}
          GOOGLE_CLIENT_ID: ${{ secrets.GOOGLE_CLIENT_ID }}
          GOOGLE_CLIENT_SECRET: ${{ secrets.GOOGLE_CLIENT_SECRET }}
          GOOGLE_REDIRECT_URI: ${{ secrets.GOOGLE_REDIRECT_URI }}
          TOKEN_ENCRYPTION_KEY: ${{ secrets.TOKEN_ENCRYPTION_KEY }}
          SESSION_SECRET: ${{ secrets.SESSION_SECRET }}
          APP_URL: ${{ secrets.APP_URL }}
          NODE_ENV: production
          BOT_ID: ${{ matrix.bot }}
          BOT_BATCH_SIZE: ${{ github.event.inputs.batch_size || '20' }}
          BOT_DELAY_MS: '1200'
        run: node scripts/bot-parallel.js
EOF
sed -i 's/\r$//' .github/workflows/bots.yml
echo "   ✅ .github/workflows/bots.yml (3 jobs in parallel)"

# ═══════════════════════════════════════════
# 2. GITHUB TRIGGER LIB — call API from Vercel
# ═══════════════════════════════════════════
echo ""
echo "📡 [2/6] Creating GitHub trigger lib..."

mkdir -p lib

cat > lib/github-trigger.ts <<'EOF'
/**
 * Trigger GitHub Actions workflow from Vercel/backend.
 *
 * Env vars required:
 *   GITHUB_PAT   — Personal Access Token (scopes: repo, workflow)
 *   GITHUB_REPO  — "owner/repo" format (e.g. "dipenzala/emailcampaign")
 */

const GITHUB_API = 'https://api.github.com';

export async function triggerBotWorkflow(opts: {
  batchSize?: number;
  mode?: 'run' | 'once';
} = {}): Promise<{ ok: boolean; status?: number; error?: string }> {
  const pat = process.env.GITHUB_PAT;
  const repo = process.env.GITHUB_REPO || 'dipenzala/emailcampaign';

  if (!pat) {
    console.warn('[gh-trigger] GITHUB_PAT not set — skipping trigger');
    return { ok: false, error: 'GITHUB_PAT not configured' };
  }

  const url = `${GITHUB_API}/repos/${repo}/actions/workflows/bots.yml/dispatches`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ref: 'main',
        inputs: {
          batch_size: String(opts.batchSize || 20),
          mode: opts.mode || 'run',
        },
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.warn('[gh-trigger] API failed:', res.status, text.slice(0, 200));
      return { ok: false, status: res.status, error: text.slice(0, 200) };
    }

    console.log('[gh-trigger] ✅ Workflow triggered');
    return { ok: true, status: res.status };
  } catch (err: any) {
    console.error('[gh-trigger] fetch error:', err.message);
    return { ok: false, error: err.message };
  }
}
EOF
sed -i 's/\r$//' lib/github-trigger.ts
echo "   ✅ lib/github-trigger.ts"

# ═══════════════════════════════════════════
# 3. UPDATE START API — trigger GitHub on launch
# ═══════════════════════════════════════════
echo ""
echo "🚀 [3/6] Updating campaign start to trigger bots..."

mkdir -p 'app/api/campaigns/[id]/start'

cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { triggerBotWorkflow } from '@/lib/github-trigger';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  const body = await req.json().catch(() => ({}));
  const batchSize = Math.min(40, Math.max(10, parseInt(body.batchSize || '20', 10)));

  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Count queued
    const queued = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });

    if (queued === 0) {
      return NextResponse.json({ error: 'No queued recipients' }, { status: 400 });
    }

    // Ensure campaigns running
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    // Enable worker flags
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch {}

    // ═══════════════════════════════════════════
    // 🚀 TRIGGER GITHUB ACTIONS — 3 BOTS PARALLEL
    // ═══════════════════════════════════════════
    const trigger = await triggerBotWorkflow({ batchSize, mode: 'run' });

    return NextResponse.json({
      ok: true,
      queued,
      total: campaign.totalCount,
      botTrigger: {
        triggered: trigger.ok,
        status: trigger.status || null,
        error: trigger.error || null,
      },
      message: trigger.ok
        ? `✅ Campaign started. 3 bots triggered instantly.`
        : `⚠️ Campaign started. Bot trigger failed: ${trigger.error}. Will auto-run every 5 min.`,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "   ✅ Start API now triggers bots"

# ═══════════════════════════════════════════
# 4. UPDATE LOCAL-SENDER — also trigger GitHub
# ═══════════════════════════════════════════
echo ""
echo "🔧 [4/6] Adding trigger to other entry points..."

# Update bot-parallel.js — ensure it handles errors and exits cleanly
if [ -f "scripts/bot-parallel.js" ]; then
  echo "   ✅ bot-parallel.js exists"
else
  echo "   ⚠️  bot-parallel.js missing — creating"
  cat > scripts/bot-parallel.js <<'EOF'
#!/usr/bin/env node
require('dotenv').config();
const BOT_ID = process.env.BOT_ID || 'bot1';
const BATCH = parseInt(process.env.BOT_BATCH_SIZE || '20', 10);
const DELAY = parseInt(process.env.BOT_DELAY_MS || '1200', 10);
const APP_URL = process.env.APP_URL || 'http://localhost:3000';

const stats = { sent: 0, failed: 0 };

async function main() {
  console.log(`🤖 ${BOT_ID} | batch=${BATCH} | delay=${DELAY}ms`);

  let prisma, google, crypto;

  try {
    const { PrismaClient } = require('@prisma/client');
    prisma = new PrismaClient();
    const g = require('googleapis');
    google = g.google;
    crypto = require('crypto');
  } catch (e) {
    console.error('❌ Module load failed:', e.message);
    process.exit(1);
  }

  const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');

  function decrypt(p) {
    try {
      const buf = Buffer.from(p, 'base64');
      const iv = buf.subarray(0, 12);
      const tag = buf.subarray(12, 28);
      const d = buf.subarray(28);
      const dc = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
      dc.setAuthTag(tag);
      return Buffer.concat([dc.update(d), dc.final()]).toString('utf8');
    } catch { return null; }
  }

  function encrypt(plain) {
    const iv = crypto.randomBytes(12);
    const c = crypto.createCipheriv('aes-256-gcm', KEY, iv);
    const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
    return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
  }

  function oauth() {
    return new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
  }

  function buildMime(o) {
    const b = '=_b_' + Math.random().toString(36).slice(2);
    const h = [
      `From: ${o.from}`, `To: ${o.to}`,
      `Subject: =?UTF-8?B?${Buffer.from(o.subject).toString('base64')}?=`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${b}"`,
    ];
    if (o.unsubUrl) {
      h.push(`List-Unsubscribe: <${o.unsubUrl}>`);
      h.push('List-Unsubscribe-Post: List-Unsubscribe=One-Click');
    }
    const body = `--${b}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(o.text).toString('base64')}

--${b}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(o.html).toString('base64')}

--${b}--`;
    return h.join('\r\n') + '\r\n\r\n' + body;
  }

  function htmlToText(h) {
    return h.replace(/<style[\s\S]*?<\/style>/gi, '')
      .replace(/<script[\s\S]*?<\/script>/gi, '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<[^>]+>/g, '')
      .replace(/\n{3,}/g, '\n\n').trim();
  }

  function renderTemplate(t, data) {
    if (!t) return '';
    return t.replace(/\{\{\s*(\w+)(?:\s*\|\s*default\s*:\s*"([^"]*)")?\s*\}\}/g, (_, k, def) => {
      const v = data[k];
      return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
    });
  }

  function getLabel(c) {
    const n = String(c?.name || '').trim();
    if (n) return n;
    const co = String(c?.company || '').trim();
    if (co) return co;
    const e = String(c?.email || '');
    if (!e) return 'Friend';
    const local = e.split('@')[0] || '';
    const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
    if (!clean) return 'Friend';
    return clean.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
  }

  function formatSubject(t, c) {
    if (!t) return '';
    const label = getLabel(c);
    const subject = t.trim();
    if (/\{\{\s*(name|company)/i.test(subject)) {
      return renderTemplate(subject, { name: c.name || label, company: c.company || label, email: c.email || '' });
    }
    if (/^congratulations/i.test(subject)) {
      const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
      return rest ? `CONGRATULATIONS 🎉 ${label} — ${rest}` : `CONGRATULATIONS 🎉 ${label}`;
    }
    return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
  }

  // Fetch queued
  const recips = await prisma.campaignRecipient.findMany({
    where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    include: { contact: true, campaign: true },
    take: BATCH,
    orderBy: { queuedAt: 'asc' },
  });

  if (recips.length === 0) {
    console.log('💤 No queued emails');
    await prisma.$disconnect();
    process.exit(0);
  }

  console.log(`📬 Claimed ${recips.length} emails`);

  for (const r of recips) {
    try {
      // Atomic claim — mark processing
      const update = await prisma.campaignRecipient.updateMany({
        where: { id: r.id, status: 'QUEUED' },
        data: { status: 'PROCESSING', attemptCount: { increment: 1 } },
      });

      if (update.count === 0) {
        // Already claimed by another bot
        continue;
      }

      // Suppression
      const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
      if (sup) {
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
        });
        continue;
      }

      // Sender
      const sender = await prisma.senderAccount.findFirst({
        where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true, sentToday: { lt: 350 } },
        orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
      });

      if (!sender) {
        await prisma.campaignRecipient.update({
          where: { id: r.id }, data: { status: 'QUEUED' },
        });
        console.log('⏸️  No sender — stopping');
        break;
      }

      // Build
      const data = {
        name: r.contact.name || '',
        email: r.contact.email,
        company: r.contact.company || '',
        city: r.contact.city || '',
        phone: r.contact.phone || '',
      };

      const finalSubject = formatSubject(r.campaign.subject, data);
      let html = renderTemplate(r.campaign.html, data);

      const pixel = `<img src="${APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
      html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

      // Send
      const access = sender.accessToken ? decrypt(sender.accessToken) : '';
      const refresh = decrypt(sender.refreshToken);
      const c = oauth();
      c.setCredentials({ access_token: access, refresh_token: refresh });
      const gmail = google.gmail({ version: 'v1', auth: c });

      const unsubUrl = `${APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
      const raw = buildMime({
        from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
        to: r.contact.email,
        subject: finalSubject,
        html,
        text: htmlToText(html),
        unsubUrl,
      });

      const res = await gmail.users.messages.send({
        userId: 'me',
        requestBody: { raw: Buffer.from(raw).toString('base64url') },
      });

      try {
        if (res.data.id) {
          await gmail.users.messages.modify({
            userId: 'me', id: res.data.id,
            requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
          });
        }
      } catch {}

      // Update DB
      await prisma.campaignRecipient.update({
        where: { id: r.id },
        data: {
          status: 'SENT',
          senderAccountId: sender.id,
          providerMessageId: res.data.id,
          sentAt: new Date(),
        },
      });

      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
      });

      if (access && refresh) {
        await prisma.senderAccount.update({
          where: { id: sender.id },
          data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
        }).catch(() => {});
      }

      stats.sent++;
      console.log(`✅ [${sender.email}] → ${r.contact.email}`);

      await new Promise(r => setTimeout(r, DELAY));
    } catch (err) {
      stats.failed++;
      console.log(`❌ ${r.contact.email}: ${(err.message || 'error').slice(0, 80)}`);

      await prisma.campaignRecipient.update({
        where: { id: r.id },
        data: { status: 'FAILED', errorMessage: (err.message || '').slice(0, 200) },
      }).catch(() => {});

      if (/rate|quota|429/i.test(err.message || '')) break;
    }
  }

  // Recalc counters
  const campaignIds = [...new Set(recips.map(r => r.campaignId))];
  for (const cid of campaignIds) {
    const [s, t] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId: cid, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId: cid } }),
    ]);
    await prisma.campaign.update({
      where: { id: cid },
      data: { sentCount: s, totalCount: t },
    }).catch(() => {});
  }

  console.log('');
  console.log(`📊 ${BOT_ID} DONE — Sent: ${stats.sent} | Failed: ${stats.failed}`);

  await prisma.$disconnect();
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
EOF
  sed -i 's/\r$//' scripts/bot-parallel.js
  chmod +x scripts/bot-parallel.js
fi

# ═══════════════════════════════════════════
# 5. UPDATE ENV EXAMPLE
# ═══════════════════════════════════════════
echo ""
echo "🔑 [5/6] Adding GitHub env vars to example..."

if [ -f ".env.example" ]; then
  if ! grep -q "GITHUB_PAT" .env.example; then
    cat >> .env.example <<'EOF'

# GitHub Actions trigger (for auto-bot)
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_REPO=dipenzala/emailcampaign
EOF
  fi
fi

# ═══════════════════════════════════════════
# 6. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: auto-trigger 3 GitHub bots on campaign launch"

git push -u origin main 2>&1 | tail -8

echo ""
echo "==============================================="
echo " ✅ AUTO-TRIGGER DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Setup — 3 STEPS (2 min)"
echo ""
echo "STEP 1: Create GitHub Personal Access Token"
echo "   Kholo: https://github.com/settings/tokens/new"
echo "   ├─ Note: EmailCampaign Auto-Trigger"
echo "   ├─ Expiration: 90 days (ya No expiration)"
echo "   └─ Scopes: ✅ repo  ✅ workflow"
echo "   → Generate → Token COPY karo (ghp_xxx...)"
echo ""
echo "STEP 2: Add env vars to Vercel"
echo "   Kholo: https://vercel.com/certwinx/emailcampaign-ten/settings/environment-variables"
echo ""
echo "   Add 2 new variables:"
echo "     GITHUB_PAT   = ghp_xxxxx  (paste karo)"
echo "     GITHUB_REPO  = dipenzala/emailcampaign"
echo ""
echo "   → Save → Redeploy"
echo ""
echo "STEP 3: Test karo"
echo "   • /campaigns/new → campaign banao"
echo "   • LAUNCH dabao"
echo "   • 10-20 sec me 3 bots GitHub pe trigger honge"
echo "   • https://github.com/dipenzala/emailcampaign/actions"
echo ""
echo "📊 HOW IT WORKS NOW:"
echo ""
echo "   User LAUNCH dabao"
echo "        ↓"
echo "   Vercel API → GitHub API call"
echo "        ↓"
echo "   GitHub Actions: 3 bots PARALLEL"
echo "        ↓"
echo "   Each bot sends 20 emails (atomic claim)"
echo "        ↓"
echo "   60 emails in ~30 sec"
echo "        ↓"
echo "   Auto-runs every 5 min (schedule)"
echo ""
echo "⚡ SPEED:"
echo "   • Old: 1 bot every 5 min = 240/hr"
echo "   • New: 3 bots on launch + 5 min schedule = 720/hr+"
echo ""
echo "✅ Also auto-runs if launch trigger fails (5 min schedule)"
echo "==============================================="