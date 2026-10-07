require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');
const http = require('http');

const prisma = new PrismaClient();
const POLL_MS = 3000;
const BATCH = 3;

const state = { startedAt: new Date(), totalSent: 0, totalFailed: 0 };

// ═══════════════════════════════════════════
// HEALTH SERVER
// ═══════════════════════════════════════════
http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      uptime: Math.floor((Date.now() - state.startedAt.getTime()) / 1000),
      totalSent: state.totalSent,
      totalFailed: state.totalFailed,
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
}).listen(3001, () => console.log('[health] :3001'));

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════
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

// ═══════════════════════════════════════════
// SUBJECT FORMATTER — CONGRATULATIONS + LABEL
// ═══════════════════════════════════════════
function getDisplayLabel(contact) {
  const name = String(contact?.name || '').trim();
  if (name) return name;

  const company = String(contact?.company || '').trim();
  if (company) return company;

  const email = String(contact?.email || '').trim();
  if (!email) return 'Friend';

  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';

  return clean.split(/\s+/).filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
}

function formatSubject(template, contact) {
  if (!template) return '';
  const label = getDisplayLabel(contact);
  const subject = template.trim();

  // Rule 1: has variable
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }

  // Rule 2: starts with CONGRATULATIONS
  if (/^congratulations/i.test(subject)) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${label} — ${rest}`
      : `CONGRATULATIONS 🎉 ${label}`;
  }

  // Rule 3: prepend
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

// ═══════════════════════════════════════════
// SENDER PICK
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
// SEND ONE
// ═══════════════════════════════════════════
async function sendViaGmail(sender, to, subject, html, text, unsubUrl) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
    to, subject, html, text, unsubUrl,
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

  return res.data.id;
}

async function processOne(r) {
  const campaign = await prisma.campaign.findUnique({ where: { id: r.campaignId } });
  if (!campaign || campaign.status !== 'RUNNING') return;

  const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    return;
  }

  await prisma.campaignRecipient.update({
    where: { id: r.id },
    data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
  });

  const sender = await pickSender(campaign.batchLimit ?? 1);
  if (!sender) {
    await prisma.campaignRecipient.update({
      where: { id: r.id }, data: { status: 'QUEUED' },
    });
    return;
  }

  const contact = r.contact;
  const recipientData = {
    name: contact.name || '',
    email: contact.email,
    company: contact.company || '',
    city: contact.city || '',
    phone: contact.phone || '',
  };

  const finalSubject = formatSubject(campaign.subject, recipientData);
  let html = renderTemplate(campaign.html, recipientData);

  const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
  html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

  console.log(`📤 [${sender.email}] → ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

  try {
    const providerMessageId = await sendViaGmail(
      sender, contact.email, finalSubject, html, htmlToText(html), unsubUrl
    );

    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId,
        sentAt: new Date(),
      },
    });
    await prisma.campaign.update({
      where: { id: campaign.id }, data: { sentCount: { increment: 1 } },
    });
    await prisma.senderAccount.update({
      where: { id: sender.id },
      data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
    });

    state.totalSent++;
    console.log(`   ✅ SENT`);
  } catch (err) {
    state.totalFailed++;
    const msg = err?.message || 'failed';
    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: {
        status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
        errorMessage: msg.slice(0, 200),
      },
    });
    console.log(`   ❌ ${msg.slice(0, 80)}`);
  }
}

// ⚡ DAILY RESET helper
async function autoResetIfNewDay() {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const stale = await prisma.senderAccount.findMany({
    where: { lastResetAt: { lt: startOfToday } },
    select: { id: true, email: true, sentToday: true },
  });
  if (stale.length === 0) return 0;
  await prisma.senderAccount.updateMany({
    where: { id: { in: stale.map(s => s.id) } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  console.log(`🔄 [daily-reset] Reset ${stale.length} sender(s)`);
  return stale.length;
}

let busy = false;
async function poll() {
  if (busy) return;
  busy = true;
  try {
    // Daily reset check
    await autoResetIfNewDay().catch(() => {});
    
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: {
          status: 'RUNNING',
          OR: [
            { approvalRequired: false },
            { approvalStatus: 'APPROVED' },
          ],
        },
      },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });
    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued`);
      for (const r of recips) await processOne(r);
    }
  } catch (e) {
    console.error('Poll error:', e.message);
  } finally {
    busy = false;
  }
}

console.log('\n🚀 WORKER (with subject personalization)');
console.log('   Poll:', POLL_MS / 1000 + 's');
console.log('');

poll();
setInterval(poll, POLL_MS);

process.on('SIGTERM', async () => { await prisma.$disconnect(); process.exit(0); });
process.on('SIGINT', async () => { await prisma.$disconnect(); process.exit(0); });
