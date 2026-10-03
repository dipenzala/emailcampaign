#!/usr/bin/env bash

echo "==============================================="
echo " 🚀 LOCAL SENDER (No Redis, No BullMQ)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Load .env
# ==========================================
if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila. Pehle banao:"
  echo "   nano .env"
  exit 1
fi

set -a
source .env
set +a
echo "✅ .env loaded"
echo "   DB:  ${DATABASE_URL:0:45}..."
echo ""

# ==========================================
# 2. Check tsx
# ==========================================
if [ ! -f "node_modules/.bin/tsx" ] && [ ! -f "node_modules/tsx/dist/cli.mjs" ]; then
  echo "⚠️  tsx not found. Installing..."
  npm install --ignore-scripts tsx --silent 2>&1 | tail -2
fi

# ==========================================
# 3. Write standalone worker JS
# ==========================================
echo "📝 Writing local-sender.js..."

cat > local-sender.js <<'JSEOF'
// ==========================================
// Pure DB polling worker — NO Redis, NO BullMQ
// ==========================================
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const prisma = new PrismaClient();
const POLL_MS = 2000;
const BATCH = 3;

// ---------- Crypto ----------
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
function decrypt(payload) {
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(data), d.final()]).toString('utf8');
}

// ---------- OAuth ----------
function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

// ---------- MIME ----------
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

function renderTemplate(html, data) {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_, k, def) => {
    const v = data[k];
    return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
  });
}

// ---------- Warm-up ----------
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];
function effectiveLimit(s) {
  if (!s.warmupEnabled) return s.dailyLimit;
  const t = TIERS.find(x => s.warmupDay <= x.maxDay);
  return t ? Math.min(t.limit, s.dailyLimit) : s.dailyLimit;
}

// ---------- Pick sender ----------
async function pickSender(batchLimit) {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
  });
  for (const s of senders) {
    if (s.batchCount < batchLimit) return s;
  }
  // Reset batch counts
  await prisma.senderAccount.updateMany({
    where: { status: 'CONNECTED', isActive: true },
    data: { batchCount: 0 },
  });
  return senders[0] || null;
}

// ---------- Send one ----------
async function sendOne(recipient) {
  const campaign = await prisma.campaign.findUnique({ where: { id: recipient.campaignId } });
  if (!campaign || campaign.status !== 'RUNNING') return false;

  // Suppression
  const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({ where: { id: campaign.id }, data: { suppressedCount: { increment: 1 } } });
    console.log(`⏭️  SUPPRESSED: ${recipient.contact.email} (${sup.reason})`);
    return true;
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipient.id },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // Pick sender
  const sender = await pickSender(campaign.batchLimit ?? 10);
  if (!sender) {
    console.log('❌ No sender available');
    await prisma.campaignRecipient.update({ where: { id: recipient.id }, data: { status: 'QUEUED' } });
    return false;
  }

  // Warm-up check
  const cap = effectiveLimit(sender);
  if (sender.sentToday >= cap) {
    console.log(`⏸️  Warm-up cap: ${sender.email} (${sender.sentToday}/${cap})`);
    await prisma.campaignRecipient.update({ where: { id: recipient.id }, data: { status: 'QUEUED' } });
    return false;
  }

  // Build + send
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  const html = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  const text = htmlToText(html);

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to: recipient.contact.email,
    subject: campaign.subject,
    html,
    text,
    unsubUrl,
  });

  try {
    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });

    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId: res.data.id,
        sentAt: new Date(),
        errorCode: null,
        errorMessage: null,
      },
    });
    await prisma.campaign.update({ where: { id: campaign.id }, data: { sentCount: { increment: 1 } } });
    await prisma.senderAccount.update({
      where: { id: sender.id },
      data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
    });

    console.log(`✅ SENT [${sender.email}] → ${recipient.contact.email}`);

    // Check complete
    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 CAMPAIGN COMPLETED');
    }
    return true;
  } catch (err) {
    const msg = err?.message ?? 'Send failed';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);

    if (isBounce) {
      await prisma.suppressionList.upsert({
        where: { email: recipient.contact.email },
        create: { email: recipient.contact.email, reason: 'BOUNCED' },
        update: {},
      });
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } },
      });
      console.log(`⚠️  BOUNCED: ${recipient.contact.email}`);
    } else if (recipient.attemptCount < 3) {
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'QUEUED', errorMessage: msg },
      });
      console.log(`🔄 RETRY: ${recipient.contact.email} (${msg.slice(0, 60)})`);
    } else {
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'FAILED', errorCode: String(err?.code ?? 'ERR'), errorMessage: msg, failedAt: new Date() },
      });
      await prisma.campaign.update({ where: { id: campaign.id }, data: { failedCount: { increment: 1 } } });
      console.log(`❌ FAILED: ${recipient.contact.email} (${msg.slice(0, 60)})`);
    }
    return false;
  }
}

// ---------- Poll loop ----------
let busy = false;
async function poll() {
  if (busy) return;
  busy = true;
  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued — processing...`);
      for (const r of recips) await sendOne(r);
    }
  } catch (e) {
    console.error('Poll error:', e.message);
  } finally {
    busy = false;
  }
}

// ---------- Start ----------
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🚀 LOCAL SENDER (Pure DB polling)');
console.log('═══════════════════════════════════════════');
console.log('   Poll every:  ' + (POLL_MS / 1000) + 's');
console.log('   Batch:       ' + BATCH);
console.log('   No Redis. No BullMQ. Just Prisma + Gmail.');
console.log('');
console.log('🎯 Listening for QUEUED recipients...');
console.log('');

poll();
setInterval(poll, POLL_MS);

process.on('SIGINT', async () => {
  console.log('\n🛑 Stopping...');
  await prisma.$disconnect();
  process.exit(0);
});
JSEOF

echo "✅ local-sender.js created"
echo ""

# ==========================================
# 4. Run it
# ==========================================
echo "==============================================="
echo " 🚀 Starting LOCAL SENDER..."
echo "==============================================="
echo ""

node local-sender.js