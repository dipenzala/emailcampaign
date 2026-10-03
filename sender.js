// ==========================================
// Smart Local Sender — No Infinite Loops
// ==========================================
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const prisma = new PrismaClient();
const POLL_MS = 5000;
const BATCH = 3;
const CAP_COOLDOWN_MS = 5 * 60 * 1000;   // 5 min pause when all capped

let stopWhenComplete = false;
let lastCapHit = 0;
let capCooldownUntil = 0;

// ---------- Crypto ----------
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
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

function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

async function testSenderToken(sender) {
  try {
    const access = sender.accessToken ? decrypt(sender.accessToken) : '';
    const refresh = decrypt(sender.refreshToken);
    if (!refresh) return null;
    const c = oauthClient();
    c.setCredentials({ access_token: access, refresh_token: refresh });
    await c.getAccessToken();
    return c;
  } catch (err) {
    const msg = err.message || '';
    if (/insufficient|permission|invalid_grant|expired|revoked/i.test(msg)) {
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { status: 'DISCONNECTED', isActive: false },
      }).catch(() => {});
    }
    return null;
  }
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

function renderTemplate(html, data) {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_, k, def) => {
    const v = data[k];
    return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
  });
}

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

async function poll(oauthClients) {
  // Stop if campaign complete
  if (stopWhenComplete) return;

  // Cooldown after warm-up cap
  if (Date.now() < capCooldownUntil) return;

  const recips = await prisma.campaignRecipient.findMany({
    where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    include: { contact: true },
    take: BATCH,
    orderBy: { queuedAt: 'asc' },
  });

  if (recips.length === 0) {
    // Check if any campaign is COMPLETED
    const running = await prisma.campaign.count({ where: { status: 'RUNNING' } });
    if (running === 0) {
      console.log('⏸️  No running campaigns — waiting');
      capCooldownUntil = Date.now() + 60000; // 1 min idle
    }
    return;
  }

  console.log(`\n📬 ${recips.length} queued — processing...`);

  const senders = await prisma.senderAccount.findMany({
    where: { email: { in: Object.keys(oauthClients) } },
    orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
  });

  let anySent = false;
  let allCapped = true;

  for (const recipient of recips) {
    const campaign = await prisma.campaign.findUnique({ where: { id: recipient.campaignId } });
    if (!campaign || campaign.status !== 'RUNNING') continue;

    // Suppression
    const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
    if (sup) {
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
      });
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { suppressedCount: { increment: 1 } },
      });
      console.log(`⏭️  SKIP ${recipient.contact.email}`);
      continue;
    }

    // Find available sender
    let sender = null;
    for (const s of senders) {
      const cap = effectiveLimit(s);
      if (s.sentToday < cap && s.batchCount < (campaign.batchLimit ?? 10)) {
        sender = s;
        break;
      }
    }

    if (!sender) {
      // All senders capped — put recipient back, set cooldown, break
      break;
    }

    allCapped = false;

    // Mark processing
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
    });

    const c = oauthClients[sender.email];
    const gmail = google.gmail({ version: 'v1', auth: c });
    const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
    const html = renderTemplate(campaign.html, {
      name: recipient.contact.name ?? '',
      email: recipient.contact.email,
      company: recipient.contact.company ?? '',
      city: recipient.contact.city ?? '',
      phone: recipient.contact.phone ?? '',
    });

    try {
      const raw = buildMime({
        from: `${sender.displayName ?? sender.email} <${sender.email}>`,
        to: recipient.contact.email,
        subject: campaign.subject,
        html,
        text: htmlToText(html),
        unsubUrl,
      });
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
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { sentCount: { increment: 1 } },
      });
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: {
          sentToday: { increment: 1 },
          batchCount: { increment: 1 },
          lastSuccessAt: new Date(),
        },
      });

      console.log(`✅ SENT [${sender.email}] → ${recipient.contact.email}`);
      anySent = true;

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
        stopWhenComplete = true;
      }
    } catch (err) {
      const msg = err?.message ?? 'Send failed';
      const isPermanent = /insufficient|permission|invalid_grant|unauthorized|550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient|not found/i.test(msg);
      if (isPermanent) {
        await prisma.suppressionList.upsert({
          where: { email: recipient.contact.email },
          create: { email: recipient.contact.email, reason: 'MANUAL_BLOCK' },
          update: {},
        }).catch(() => {});
        await prisma.campaignRecipient.update({
          where: { id: recipient.id },
          data: { status: 'SUPPRESSED', errorCode: 'AUTO_SUPPRESSED', errorMessage: msg.slice(0, 200) },
        });
        console.log(`⛔ SUPPRESSED ${recipient.contact.email}`);
      } else {
        await prisma.campaignRecipient.update({
          where: { id: recipient.id },
          data: { status: 'QUEUED', errorMessage: msg.slice(0, 200) },
        });
        console.log(`🔄 RETRY ${recipient.contact.email}`);
      }
    }
  }

  // If nothing could be sent (all capped), set cooldown
  if (!anySent && allCapped) {
    const now = Date.now();
    if (now - lastCapHit < 10000) {
      // Already logged recently, extend cooldown
      capCooldownUntil = now + CAP_COOLDOWN_MS;
      console.log(`⏸️  All senders capped — pausing 5 min`);
    }
    lastCapHit = now;
  }
}

(async () => {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(' 🚀 Smart Sender (with cap cooldown)');
  console.log('═══════════════════════════════════════════');
  console.log('   Poll:     ' + (POLL_MS / 1000) + 's');
  console.log('   Batch:    ' + BATCH);
  console.log('   Cap pause: 5 min');
  console.log('');

  // Test senders
  const senders = await prisma.senderAccount.findMany({ where: { status: 'CONNECTED' } });
  const oauthClients = {};
  console.log('🔍 Testing sender tokens...');
  for (const s of senders) {
    process.stdout.write(`   ${s.email}... `);
    const client = await testSenderToken(s);
    if (client) {
      oauthClients[s.email] = client;
      const cap = effectiveLimit(s);
      console.log(`✅ OK (${s.sentToday}/${cap} today)`);
    } else {
      console.log('❌ FAILED');
    }
  }
  console.log('');
  console.log(`✅ Working: ${Object.keys(oauthClients).length}/${senders.length}`);
  console.log('');

  if (Object.keys(oauthClients).length === 0) {
    console.log('❌ No working senders. Reconnect at /senders');
    process.exit(1);
  }

  console.log('🎯 Listening for QUEUED recipients...');
  console.log('');
  poll(oauthClients);
  setInterval(() => poll(oauthClients), POLL_MS);
})().catch(e => { console.error('Fatal:', e.message); process.exit(1); });
