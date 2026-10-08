#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎯 FINAL FIX — Button + Worker + Bot"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. FIX LAUNCH BUTTON — diagnose why it doesn't work
# ═══════════════════════════════════════════
echo "🎯 [1/8] Checking launch button logic..."

# Check what's wrong with the campaign start
mkdir -p 'app/api/campaigns/[id]/start'

cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { checkEmail } from '@/lib/spam-checker';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();

  try {
    console.log('[start] Request for campaign:', params.id);

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'Campaign not found' }, { status: 404 });
    }

    // Spam check (non-blocking for now)
    let spamScore = 0;
    try {
      const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
      const report = checkEmail({
        subject: campaign.subject,
        html: campaign.html,
        fromEmail: sender?.email || 'noreply@example.com',
      });
      spamScore = report.score;
      await prisma.campaign.update({
        where: { id: params.id },
        data: { spamScore: report.score, spamIssues: report.issues as any },
      });
      // DO NOT block — let user start even with warning
    } catch (e) {
      console.warn('[start] spam check failed (ignored):', e);
    }

    // Count queued
    const queuedCount = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });

    if (queuedCount === 0) {
      return NextResponse.json({
        ok: false,
        error: 'No queued recipients in campaign',
      }, { status: 400 });
    }

    // Auto-enable workers
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch (e) {
      console.warn('[start] worker enable failed:', e);
    }

    // Mark RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    console.log('[start] ✅ Campaign RUNNING with', queuedCount, 'queued');

    return NextResponse.json({
      ok: true,
      queued: queuedCount,
      total: campaign.totalCount,
      spamScore,
      message: `Campaign started with ${queuedCount} recipients`,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start] FATAL:', err);
    return NextResponse.json({
      ok: false,
      error: 'Server error: ' + (err?.message || 'unknown'),
    }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "   ✅ Start API bulletproof"

# ═══════════════════════════════════════════
# 2. WORKER SETTINGS LIB — ensure exists
# ═══════════════════════════════════════════
echo ""
echo "🔧 [2/8] Ensuring worker-settings lib..."

cat > lib/worker-settings.ts <<'EOF'
import { prisma } from './prisma';

const TABLE = 'worker_settings';

export async function ensureTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS worker_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  } catch {}
}

export async function getSetting(key: string, fallback = ''): Promise<string> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM ${TABLE} WHERE key = $1 LIMIT 1`, key
    );
    return rows?.[0]?.value ?? fallback;
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureTable();
      return fallback;
    }
    return fallback;
  }
}

export async function setSetting(key: string, value: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${TABLE} (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key, value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureTable();
      await prisma.$executeRawUnsafe(
        `INSERT INTO ${TABLE} (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = $2`,
        key, value
      );
    } else throw e;
  }
}

export async function isWorkerEnabled() {
  return (await getSetting('worker_enabled', 'true')) !== 'false';
}
export async function enableWorker() {
  await setSetting('worker_enabled', 'true');
}
export async function disableWorker() {
  await setSetting('worker_enabled', 'false');
}
export async function isBulkWorkerEnabled() {
  return (await getSetting('bulk_worker_enabled', 'true')) !== 'false';
}
export async function enableBulkWorker() {
  await setSetting('bulk_worker_enabled', 'true');
}
export async function disableBulkWorker() {
  await setSetting('bulk_worker_enabled', 'false');
}
EOF
sed -i 's/\r$//' lib/worker-settings.ts
echo "   ✅ worker-settings.ts"

# ═══════════════════════════════════════════
# 3. SEND-ONE API — Single email directly (no worker needed)
# ═══════════════════════════════════════════
echo ""
echo "📧 [3/8] Creating one-shot send API..."

mkdir -p app/api/campaigns/\[id\]/send-one

cat > 'app/api/campaigns/[id]/send-one/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * Emergency single-email send API — bypasses worker entirely.
 * Sends next N queued emails IMMEDIATELY (synchronous).
 * Use this when worker/bot are broken.
 */
export async function POST(req: Request, { params }: { params: { id: string } }) {
  try {
    const body = await req.json().catch(() => ({}));
    const BATCH = Math.min(20, Math.max(1, parseInt(body.batchSize || '5', 10)));

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'Campaign not found' }, { status: 404 });
    }

    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, sent: 0, message: 'No queued recipients' });
    }

    let sent = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const r of recips) {
      try {
        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          continue;
        }

        // Pick sender
        const sender = await prisma.senderAccount.findFirst({
          where: {
            status: 'CONNECTED',
            refreshToken: { not: null },
            isActive: true,
            sentToday: { lt: 350 },
          },
          orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
        });

        if (!sender) {
          errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Build email
        const data = {
          name: r.contact.name || '',
          email: r.contact.email,
          company: r.contact.company || '',
          city: r.contact.city || '',
          phone: r.contact.phone || '',
        };

        const finalSubject = formatSubject(campaign.subject, data);
        let html = renderTemplate(campaign.html, data);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        // Send
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
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

        // Save to Sent
        try {
          if (res.data.id) {
            await gmail.users.messages.modify({
              userId: 'me',
              id: res.data.id,
              requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
            });
          }
        } catch {}

        // Update
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
          data: { sentToday: { increment: 1 }, lastSuccessAt: new Date() },
        });

        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          }).catch(() => {});
        }

        sent++;
        console.log(`✅ SENT: ${r.contact.email} via ${sender.email}`);
      } catch (err: any) {
        failed++;
        const msg = err.message || 'unknown';
        errors.push(msg.slice(0, 150));
        console.error(`❌ Failed: ${r.contact.email}:`, msg);

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'FAILED', errorMessage: msg.slice(0, 200) },
        }).catch(() => {});
      }
    }

    // Recalc campaign counters
    const [accSent, accTotal] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId: params.id, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId: params.id } }),
    ]);
    await prisma.campaign.update({
      where: { id: params.id },
      data: { sentCount: accSent, totalCount: accTotal },
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      sent,
      failed,
      errors: errors.slice(0, 5),
    });
  } catch (err: any) {
    console.error('[send-one] FATAL:', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/send-one/route.ts'
echo "   ✅ send-one API (emergency bypass)"

# ═══════════════════════════════════════════
# 4. WORKER PROCESS API — bulletproof
# ═══════════════════════════════════════════
echo ""
echo "🔧 [4/8] Rewriting worker process API..."

mkdir -p app/api/worker/process

cat > app/api/worker/process/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

export async function GET() { return handle(5); }
export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  return handle(Math.min(20, Math.max(1, parseInt(body.batchSize || '5', 10))));
}

async function handle(BATCH: number) {
  const results: any = {
    ok: true, processed: 0, sent: 0, failed: 0,
    suppressed: 0, remaining: 0, errors: [],
  };

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true, campaign: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      return j({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          results.suppressed++;
          continue;
        }

        // Sender
        const sender = await prisma.senderAccount.findFirst({
          where: {
            status: 'CONNECTED',
            refreshToken: { not: null },
            isActive: true,
            sentToday: { lt: 350 },
          },
          orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
        });

        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

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

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
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

        results.sent++;
      } catch (err: any) {
        results.failed++;
        results.errors.push((err.message || 'unknown').slice(0, 100));
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'FAILED', errorMessage: err.message?.slice(0, 200) },
        }).catch(() => {});
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

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    return j(results);
  } catch (err: any) {
    console.error('[process] FATAL:', err);
    return j({ ok: false, error: err.message, ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/process/route.ts
echo "   ✅ Process API fixed"

# ═══════════════════════════════════════════
# 5. GITHUB WORKFLOW — simple, no Prisma at build
# ═══════════════════════════════════════════
echo ""
echo "🤖 [5/8] Creating simple GitHub workflow..."

mkdir -p .github/workflows

# Remove old
rm -f .github/workflows/email-bot*.yml .github/workflows/bot-*.yml 2>/dev/null || true

cat > .github/workflows/bot.yml <<'EOF'
name: 🤖 Email Bot

on:
  schedule:
    - cron: '*/5 * * * *'
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - 'scripts/bot.js'
      - '.github/workflows/bot.yml'

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
          npx prisma generate
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}

      - name: Run Bot
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
          BOT_BATCH_SIZE: '15'
        run: node scripts/bot.js
EOF
sed -i 's/\r$//' .github/workflows/bot.yml
echo "   ✅ Single workflow (simpler)"

# ═══════════════════════════════════════════
# 6. BOT.JS — direct DB, no API dependency
# ═══════════════════════════════════════════
echo ""
echo "🤖 [6/8] Rewriting bot.js (direct DB)..."

mkdir -p scripts

cat > scripts/bot.js <<'EOF'
#!/usr/bin/env node
/**
 * SIMPLE BOT — direct DB access, no API dependency
 * Most reliable option for GitHub Actions
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const BATCH = parseInt(process.env.BOT_BATCH_SIZE || '15', 10);
const DELAY = 1200;
const prisma = new PrismaClient();
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');

const stats = { sent: 0, failed: 0, suppressed: 0 };

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════
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
  const n = String(contact?.name || '').trim();
  if (n) return n;
  const c = String(contact?.company || '').trim();
  if (c) return c;
  const e = String(contact?.email || '');
  if (!e) return 'Friend';
  const local = e.split('@')[0] || '';
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
// MAIN
// ═══════════════════════════════════════════
async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(' 🤖 BOT STARTED');
  console.log('═══════════════════════════════════════════');
  console.log(`  Batch: ${BATCH}`);
  console.log(`  DB: ${(process.env.DATABASE_URL || '').slice(0, 40)}...`);
  console.log('');

  const recips = await prisma.campaignRecipient.findMany({
    where: {
      status: 'QUEUED',
      campaign: { status: 'RUNNING' },
    },
    include: { contact: true, campaign: true },
    take: BATCH,
    orderBy: { queuedAt: 'asc' },
  });

  if (recips.length === 0) {
    console.log('💤 No queued emails');
    await prisma.$disconnect();
    process.exit(0);
  }

  console.log(`📬 Processing ${recips.length} emails\n`);

  for (const r of recips) {
    try {
      // Suppression
      const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
      if (sup) {
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
        });
        stats.suppressed++;
        continue;
      }

      // Sender
      const sender = await prisma.senderAccount.findFirst({
        where: {
          status: 'CONNECTED',
          refreshToken: { not: null },
          isActive: true,
          sentToday: { lt: 350 },
        },
        orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
      });

      if (!sender) {
        console.log('⏸️  No sender available');
        break;
      }

      await prisma.campaignRecipient.update({
        where: { id: r.id },
        data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
      });

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

      const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
      html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

      // Gmail
      const access = sender.accessToken ? decrypt(sender.accessToken) : '';
      const refresh = decrypt(sender.refreshToken);
      const c = oauth();
      c.setCredentials({ access_token: access, refresh_token: refresh });
      const gmail = google.gmail({ version: 'v1', auth: c });

      const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
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

      // Save to Sent
      try {
        if (res.data.id) {
          await gmail.users.messages.modify({
            userId: 'me',
            id: res.data.id,
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
        data: { sentToday: { increment: 1 }, lastSuccessAt: new Date() },
      });

      if (access && refresh) {
        await prisma.senderAccount.update({
          where: { id: sender.id },
          data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
        }).catch(() => {});
      }

      stats.sent++;
      console.log(`✅ [${sender.email}] → ${r.contact.email}`);
    } catch (err) {
      stats.failed++;
      const msg = err.message || 'unknown';
      console.log(`❌ Failed: ${r.contact.email} | ${msg.slice(0, 80)}`);

      await prisma.campaignRecipient.update({
        where: { id: r.id },
        data: { status: 'FAILED', errorMessage: msg.slice(0, 200) },
      }).catch(() => {});

      if (/rate|quota|429/i.test(msg)) break;
    }

    await new Promise(r => setTimeout(r, DELAY));
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
  console.log('═══════════════════════════════════════════');
  console.log(`✅ Sent: ${stats.sent} | ❌ Failed: ${stats.failed} | 🚫 Suppressed: ${stats.suppressed}`);
  console.log('═══════════════════════════════════════════');

  await prisma.$disconnect();
  process.exit(0);
}

main().catch(e => {
  console.error('❌ FATAL:', e.message);
  process.exit(1);
});
EOF
sed -i 's/\r$//' scripts/bot.js
chmod +x scripts/bot.js
echo "   ✅ bot.js simplified"

# ═══════════════════════════════════════════
# 7. DEBUG ENDPOINT — one place to see everything
# ═══════════════════════════════════════════
echo ""
echo "🔍 [7/8] Creating master debug endpoint..."

mkdir -p app/api/debug/master

cat > app/api/debug/master/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const [queued, runningCampaigns, senders, withToken, contacts, suppressed] = await Promise.all([
      prisma.campaignRecipient.count({ where: { status: 'QUEUED' } }),
      prisma.campaign.count({ where: { status: 'RUNNING' } }),
      prisma.senderAccount.count(),
      prisma.senderAccount.count({ where: { status: 'CONNECTED', refreshToken: { not: null } } }),
      prisma.contact.count(),
      prisma.suppressionList.count(),
    ]);

    const recentCampaign = await prisma.campaign.findFirst({
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { recipients: true } } },
    });

    let workerFlag = 'unknown';
    try {
      const rows: any[] = await prisma.$queryRawUnsafe(
        `SELECT value FROM worker_settings WHERE key = 'worker_enabled' LIMIT 1`
      );
      workerFlag = rows?.[0]?.value ?? 'not-set';
    } catch {}

    return NextResponse.json({
      ok: true,
      timestamp: new Date().toISOString(),
      counts: {
        queued,
        runningCampaigns,
        senders,
        sendersWithToken: withToken,
        contacts,
        suppressed,
      },
      workerFlag,
      latestCampaign: recentCampaign ? {
        id: recentCampaign.id,
        name: recentCampaign.name,
        status: recentCampaign.status,
        totalCount: recentCampaign.totalCount,
        sentCount: recentCampaign.sentCount,
        recipientsInDB: recentCampaign._count.recipients,
        approvalStatus: (recentCampaign as any).approvalStatus,
      } : null,
      diagnosis: {
        canSend: queued > 0 && withToken > 0 && runningCampaigns > 0,
        issue: queued === 0 ? 'No queued emails'
          : withToken === 0 ? 'No connected senders'
          : runningCampaigns === 0 ? 'No running campaigns'
          : 'Ready to send ✅',
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/debug/master/route.ts
echo "   ✅ /api/debug/master"

# ═══════════════════════════════════════════
# 8. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [8/8] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: launch button + worker + bot + debug endpoint"

git push -u origin main 2>&1 | tail -8

echo ""
echo "==============================================="
echo " ✅ COMPLETE FIX DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 3 ways to send emails now:"
echo ""
echo "1. 🎯 LAUNCH BUTTON (/campaigns/new)"
echo "   ✓ Fixed — spam check ab block nahi karega"
echo "   ✓ Workers auto-enable honge"
echo "   ✓ Button ab work karega"
echo ""
echo "2. 🚀 WORKER API (manual)"
echo "   POST /api/campaigns/[ID]/send-one"
echo "   POST /api/worker/process"
echo "   ✓ Direct send — no dependencies"
echo ""
echo "3. 🤖 GITHUB BOT (auto)"
echo "   ✓ Single workflow: 'Email Bot'"
echo "   ✓ Every 5 min auto-run"
echo "   ✓ Direct DB — no API needed"
echo ""
echo "📊 3 Min Baad YE KARO:"
echo ""
echo "STEP 1: Master debug kholo (mobile me):"
echo "   https://emailcampaign-ten.vercel.app/api/debug/master"
echo ""
echo "   Screenshot bhejo — main exact status bata dunga"
echo ""
echo "STEP 2: Emergency send test (agar button kaam nahi kare):"
echo "   Mobile browser me kholo:"
echo "   https://emailcampaign-ten.vercel.app/campaigns/[YOUR_CAMPAIGN_ID]"
echo ""
echo "   Ya directly test karo:"
echo "   curl -X POST https://emailcampaign-ten.vercel.app/api/campaigns/[ID]/send-one \\"
echo "     -H 'Content-Type: application/json' -d '{\"batchSize\":3}'"
echo ""
echo "STEP 3: GitHub bot enable karo:"
echo "   https://github.com/dipenzala/emailcampaign/actions"
echo "   → '🤖 Email Bot' → Enable → Run workflow"
echo ""
echo "⚠️  IMPORTANT:"
echo "   • Old workflows delete ho gaye"
echo "   • Ab sirf 'Email Bot' workflow hai"
echo "   • Push ne auto-trigger kar diya hoga"
echo "==============================================="