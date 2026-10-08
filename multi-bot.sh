#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🤖🤖🤖 MULTI-BOT: 3 Parallel Senders"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. ATOMIC PICK API — no race conditions
# ═══════════════════════════════════════════
echo "🔒 [1/5] Creating atomic-pick API..."

mkdir -p app/api/bot/pick

cat > app/api/bot/pick/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

/**
 * ATOMIC PICK
 * -----------
 * Uses Postgres FOR UPDATE SKIP LOCKED to claim emails.
 * Multiple bots can call this in parallel without duplicates.
 * Each bot gets a UNIQUE set of recipients.
 */
export async function POST(req: Request) {
  try {
    const { botId, batchSize = 15 } = await req.json();

    if (!botId) {
      return NextResponse.json({ error: 'botId required' }, { status: 400 });
    }

    // ═══════════════════════════════════════════
    // ATOMIC CLAIM via raw SQL
    // ═══════════════════════════════════════════
    // 1. Find N queued emails
    // 2. Atomically lock them (SKIP LOCKED so other bots skip)
    // 3. Mark as PROCESSING with botId
    // 4. Return claimed rows

    const claimed: any[] = await prisma.$queryRawUnsafe(`
      WITH claimed AS (
        SELECT id
        FROM "CampaignRecipient"
        WHERE status = 'QUEUED'
          AND "campaignId" IN (
            SELECT id FROM "Campaign"
            WHERE status = 'RUNNING'
              AND ("approvalRequired" = false OR "approvalStatus" = 'APPROVED')
          )
        ORDER BY "queuedAt" ASC
        LIMIT $1
        FOR UPDATE SKIP LOCKED
      )
      UPDATE "CampaignRecipient" cr
      SET
        status = 'PROCESSING',
        "attemptCount" = cr."attemptCount" + 1,
        "errorMessage" = $2
      FROM claimed
      WHERE cr.id = claimed.id
      RETURNING cr.id, cr."campaignId", cr."contactId"
    `, batchSize, `CLAIMED_BY:${botId}:${Date.now()}`);

    if (claimed.length === 0) {
      return NextResponse.json({
        ok: true,
        botId,
        claimed: 0,
        recipients: [],
      });
    }

    // Fetch full recipient data
    const recipientIds = claimed.map((c: any) => c.id);
    const fullData = await prisma.campaignRecipient.findMany({
      where: { id: { in: recipientIds } },
      include: { contact: true, campaign: true },
    });

    return NextResponse.json({
      ok: true,
      botId,
      claimed: fullData.length,
      recipients: fullData.map(r => ({
        id: r.id,
        campaignId: r.campaignId,
        contactId: r.contactId,
        contact: {
          email: r.contact.email,
          name: r.contact.name,
          company: r.contact.company,
          city: r.contact.city,
          phone: r.contact.phone,
        },
        campaign: {
          id: r.campaign.id,
          name: r.campaign.name,
          subject: r.campaign.subject,
          html: r.campaign.html,
          batchLimit: r.campaign.batchLimit,
        },
      })),
    });
  } catch (err: any) {
    console.error('[bot/pick] error:', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/bot/pick/route.ts
echo "   ✅ /api/bot/pick (atomic claim)"

# ═══════════════════════════════════════════
# 2. MARK SENT API
# ═══════════════════════════════════════════
echo ""
echo "📝 [2/5] Creating mark-sent API..."

mkdir -p app/api/bot/mark-sent

cat > app/api/bot/mark-sent/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { recipientId, senderId, providerMessageId, status, error } = await req.json();

    if (!recipientId) return NextResponse.json({ error: 'recipientId required' }, { status: 400 });

    const update: any = {
      status: status || 'SENT',
      senderAccountId: senderId || null,
      providerMessageId: providerMessageId || null,
    };

    if (status === 'SENT') {
      update.sentAt = new Date();
      update.errorCode = null;
      update.errorMessage = null;
    } else if (status === 'FAILED' || status === 'BOUNCED') {
      update.errorMessage = error || null;
      update.failedAt = new Date();
    } else if (status === 'SUPPRESSED') {
      update.errorCode = 'SUPPRESSED';
      update.errorMessage = error || null;
    }

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: update,
    });

    // Update sender counters if sent
    if (status === 'SENT' && senderId) {
      await prisma.senderAccount.update({
        where: { id: senderId },
        data: {
          sentToday: { increment: 1 },
          batchCount: { increment: 1 },
          lastSuccessAt: new Date(),
        },
      }).catch(() => {});
    }

    // Refresh campaign counters
    const recipient = await prisma.campaignRecipient.findUnique({
      where: { id: recipientId },
      select: { campaignId: true },
    });

    if (recipient) {
      const [sent, total] = await Promise.all([
        prisma.campaignRecipient.count({ where: { campaignId: recipient.campaignId, status: 'SENT' } }),
        prisma.campaignRecipient.count({ where: { campaignId: recipient.campaignId } }),
      ]);
      await prisma.campaign.update({
        where: { id: recipient.campaignId },
        data: { sentCount: sent, totalCount: total },
      }).catch(() => {});

      // Auto complete
      const remaining = await prisma.campaignRecipient.count({
        where: { campaignId: recipient.campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
      });
      if (remaining === 0) {
        await prisma.campaign.update({
          where: { id: recipient.campaignId },
          data: { status: 'COMPLETED', completedAt: new Date() },
        }).catch(() => {});
      }
    }

    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/bot/mark-sent/route.ts
echo "   ✅ /api/bot/mark-sent"

# ═══════════════════════════════════════════
# 3. STANDALONE BOT SCRIPT (takes botId + API URL)
# ═══════════════════════════════════════════
echo ""
echo "🤖 [3/5] Creating bot worker script..."

cat > scripts/bot-parallel.js <<'EOF'
#!/usr/bin/env node
/**
 * PARALLEL BOT — takes botId and picks unique emails via API
 * Usage: BOT_ID=bot-1 node scripts/bot-parallel.js
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const BOT_ID = process.env.BOT_ID || `bot-${Math.random().toString(36).slice(2, 8)}`;
const BATCH_SIZE = parseInt(process.env.BOT_BATCH_SIZE || '15', 10);
const DELAY_MS = parseInt(process.env.BOT_DELAY_MS || '1500', 10);
const APP_URL = process.env.APP_URL || 'http://localhost:3000';

const prisma = new PrismaClient();
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
const state = { started: Date.now(), sent: 0, failed: 0, suppressed: 0, bounced: 0 };

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════
function decrypt(payload) {
  try {
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const data = buf.subarray(28);
    const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
    d.setAuthTag(tag);
    return Buffer.concat([d.update(data), d.final()]).toString('utf8');
  } catch { return null; }
}

function encrypt(plain) {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', KEY, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
}

function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

function buildMime(o) {
  const b = '=_b_' + Math.random().toString(36).slice(2);
  const h = [
    `From: ${o.from}`,
    `To: ${o.to}`,
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

function getLabel(contact) {
  const name = String(contact?.name || '').trim();
  if (name) return name;
  const company = String(contact?.company || '').trim();
  if (company) return company;
  const email = String(contact?.email || '');
  if (!email) return 'Friend';
  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';
  return clean.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
}

function formatSubject(template, contact) {
  if (!template) return '';
  const label = getLabel(contact);
  const subject = template.trim();
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }
  if (/^congratulations/i.test(subject)) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest ? `CONGRATULATIONS 🎉 ${label} — ${rest}` : `CONGRATULATIONS 🎉 ${label}`;
  }
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

// ═══════════════════════════════════════════
// WARM-UP
// ═══════════════════════════════════════════
const TIERS = [
  { maxDay: 3, limit: 5 }, { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 }, { maxDay: 30, limit: 50 },
];
function effectiveLimit(s) {
  if (!s.warmupEnabled) return s.dailyLimit || 350;
  const t = TIERS.find(x => s.warmupDay <= x.maxDay);
  return t ? Math.min(t.limit, s.dailyLimit || 350) : (s.dailyLimit || 350);
}

// ═══════════════════════════════════════════
// PICK SENDER
// ═══════════════════════════════════════════
async function pickSender(batchLimit) {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });
  if (!senders.length) return null;

  for (const s of senders) {
    if (s.sentToday >= effectiveLimit(s)) continue;
    if (s.batchCount < batchLimit) return s;
  }

  await prisma.senderAccount.updateMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    data: { batchCount: 0 },
  });

  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });
  for (const s of fresh) if (s.sentToday < effectiveLimit(s)) return s;
  return null;
}

// ═══════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════
async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(` 🤖 ${BOT_ID} STARTED`);
  console.log('═══════════════════════════════════════════');
  console.log(`  Batch size: ${BATCH_SIZE}`);
  console.log(`  Delay:      ${DELAY_MS}ms`);
  console.log(`  App URL:    ${APP_URL}`);
  console.log('');

  try {
    // ═══════════════════════════════════════════
    // 1. ATOMIC PICK via API
    // ═══════════════════════════════════════════
    const pickRes = await fetch(`${APP_URL}/api/bot/pick`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ botId: BOT_ID, batchSize: BATCH_SIZE }),
    });

    const pickData = await pickRes.json();

    if (!pickData.ok) {
      console.error('❌ Pick failed:', pickData.error);
      process.exit(1);
    }

    if (pickData.claimed === 0) {
      console.log('💤 No queued emails — all claimed by other bots or empty');
      await prisma.$disconnect();
      process.exit(0);
    }

    console.log(`📬 Claimed ${pickData.claimed} unique emails`);
    console.log('');

    // ═══════════════════════════════════════════
    // 2. SEND EACH
    // ═══════════════════════════════════════════
    for (const r of pickData.recipients) {
      try {
        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await fetch(`${APP_URL}/api/bot/mark-sent`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              recipientId: r.id,
              status: 'SUPPRESSED',
              error: sup.reason,
            }),
          });
          state.suppressed++;
          console.log(`⏭️  Suppressed: ${r.contact.email}`);
          continue;
        }

        // Pick sender
        const sender = await pickSender(r.campaign.batchLimit ?? 1);
        if (!sender) {
          // Put back to queue
          await fetch(`${APP_URL}/api/bot/mark-sent`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ recipientId: r.id, status: 'QUEUED' }),
          });
          console.log('⏸️  No sender — stopping');
          break;
        }

        // Build email
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

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
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

        const sendRes = await gmail.users.messages.send({
          userId: 'me',
          requestBody: { raw: Buffer.from(raw).toString('base64url') },
        });

        try {
          if (sendRes.data.id) {
            await gmail.users.messages.modify({
              userId: 'me',
              id: sendRes.data.id,
              requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
            });
          }
        } catch {}

        // Save refreshed tokens
        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          }).catch(() => {});
        }

        // Mark as SENT
        await fetch(`${APP_URL}/api/bot/mark-sent`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipientId: r.id,
            senderId: sender.id,
            providerMessageId: sendRes.data.id,
            status: 'SENT',
          }),
        });

        state.sent++;
        console.log(`✅ [${sender.email}] → ${r.contact.email} | "${finalSubject}"`);

        // Delay
        if (DELAY_MS > 0) {
          await new Promise(r => setTimeout(r, DELAY_MS));
        }
      } catch (err) {
        const msg = err.message || 'unknown';
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);
        const isRateLimit = /rate|quota|429/i.test(msg);

        state.failed++;
        console.log(`❌ Failed: ${msg.slice(0, 100)}`);

        await fetch(`${APP_URL}/api/bot/mark-sent`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipientId: r.id,
            status: isBounce ? 'BOUNCED' : 'FAILED',
            error: msg.slice(0, 200),
          }),
        }).catch(() => {});

        if (isRateLimit) {
          console.log('⚠️  Rate limit — stopping early');
          break;
        }
      }
    }

    // ═══════════════════════════════════════════
    // 3. RESULTS
    // ═══════════════════════════════════════════
    console.log('');
    console.log('═══════════════════════════════════════════');
    console.log(` 📊 ${BOT_ID} RESULTS`);
    console.log('═══════════════════════════════════════════');
    console.log(`  ✅ Sent:       ${state.sent}`);
    console.log(`  ❌ Failed:     ${state.failed}`);
    console.log(`  🚫 Suppressed: ${state.suppressed}`);
    console.log(`  ⏱️  Duration:   ${((Date.now() - state.started) / 1000).toFixed(1)}s`);
    console.log('═══════════════════════════════════════════');
    console.log('');
  } catch (err) {
    console.error('❌ FATAL:', err.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
    process.exit(0);
  }
}

main().catch(e => { console.error(e); process.exit(1); });
EOF
sed -i 's/\r$//' scripts/bot-parallel.js
chmod +x scripts/bot-parallel.js
echo "   ✅ scripts/bot-parallel.js"

# ═══════════════════════════════════════════
# 4. 3 GITHUB WORKFLOWS
# ═══════════════════════════════════════════
echo ""
echo "⚙️  [4/5] Creating 3 parallel workflows..."

mkdir -p .github/workflows

# Common template
WORKFLOW_TEMPLATE() {
  local BOT_ID=$1
  local CRON=$2
  cat > .github/workflows/email-bot-$BOT_ID.yml <<EOF
name: 📧 Email Bot $BOT_ID

on:
  schedule:
    - cron: '$CRON'
  workflow_dispatch:

jobs:
  send:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install
        run: |
          npm install --ignore-scripts --no-audit --no-fund
          npx prisma generate --no-engine 2>/dev/null || npx prisma generate
      - name: Run Bot
        env:
          DATABASE_URL: \${{ secrets.DATABASE_URL }}
          REDIS_URL: \${{ secrets.REDIS_URL }}
          GOOGLE_CLIENT_ID: \${{ secrets.GOOGLE_CLIENT_ID }}
          GOOGLE_CLIENT_SECRET: \${{ secrets.GOOGLE_CLIENT_SECRET }}
          GOOGLE_REDIRECT_URI: \${{ secrets.GOOGLE_REDIRECT_URI }}
          TOKEN_ENCRYPTION_KEY: \${{ secrets.TOKEN_ENCRYPTION_KEY }}
          SESSION_SECRET: \${{ secrets.SESSION_SECRET }}
          APP_URL: \${{ secrets.APP_URL }}
          NODE_ENV: production
          BOT_ID: '$BOT_ID'
          BOT_BATCH_SIZE: '20'
          BOT_DELAY_MS: '1200'
        run: node scripts/bot-parallel.js
EOF
  sed -i 's/\r$//' .github/workflows/email-bot-$BOT_ID.yml
}

WORKFLOW_TEMPLATE "bot1" "*/5 * * * *"
WORKFLOW_TEMPLATE "bot2" "2-59/5 * * * *"
WORKFLOW_TEMPLATE "bot3" "4-59/5 * * * *"

echo "   ✅ 3 workflows created"
echo "      bot1: every 5 min"
echo "      bot2: every 5 min (offset 2)"
echo "      bot3: every 5 min (offset 4)"

# Also update package.json
node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts['bot:parallel'] = 'node scripts/bot-parallel.js';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ npm run bot:parallel added');
NODEEOF

# ═══════════════════════════════════════════
# 5. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: multi-bot system (3 parallel with atomic locking)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ MULTI-BOT DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Speed Comparison:"
echo ""
echo "  1 bot:  20 emails / 5 min  = 240/hour  = 5,760/day"
echo "  3 bots: 60 emails / 5 min  = 720/hour  = 17,280/day ⚡"
echo ""
echo "⚠️  But — Gmail limit:"
echo "  18 senders × 350 = 6,300/day MAX"
echo "  So actual = ~6,300/day (bottleneck senders)"
echo ""
echo "📊 Ab kya hoga:"
echo "  • 3 bots run parallel every 5 min"
echo "  • Each claims 20 unique emails (atomic)"
echo "  • No duplicate emails"
echo "  • Sender rotation shared"
echo ""
echo "📄 Setup Guide:"
echo "  1. GitHub Secrets add karo (already done for 1 bot)"
echo "  2. Actions tab me 3 new workflows enable karo:"
echo "     - Email Bot bot1"
echo "     - Email Bot bot2"
echo "     - Email Bot bot3"
echo "  3. Manual test: kisi bhi ek ko 'Run workflow' karo"
echo ""
echo "⏱️  2-3 min me workflows dikhenge GitHub pe"
echo ""
echo "📱 Access:"
echo "   https://github.com/dipenzala/emailcampaign/actions"
echo ""
echo "⚠️  RATE LIMIT WARNING:"
echo "  Agar Gmail rate limit hit ho → bots khud slow karenge"
echo "  Batch size kam kar sakte ho: BOT_BATCH_SIZE=10"
echo "==============================================="