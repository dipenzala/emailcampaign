#!/usr/bin/env node
/**
 * EMAIL BOT — standalone, runs anywhere
 * - Reads QUEUED recipients from DB
 * - Sends via Gmail API
 * - Logs everything
 * - Exits cleanly (no infinite loop)
 * - Auto-restart friendly
 *
 * Usage: node scripts/bot.js
 * Env: DATABASE_URL, GOOGLE_*, TOKEN_ENCRYPTION_KEY, APP_URL
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const prisma = new PrismaClient();
const BATCH_SIZE = parseInt(process.env.BOT_BATCH_SIZE || '15', 10);
const DELAY_MS = parseInt(process.env.BOT_DELAY_MS || '1500', 10);
const MAX_RUNTIME_SEC = parseInt(process.env.BOT_MAX_RUNTIME || '50', 10);

const state = {
  started: Date.now(),
  sent: 0,
  failed: 0,
  bounced: 0,
  suppressed: 0,
  errors: [],
};

// ═══════════════════════════════════════════
// CRYPTO
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
  } catch (e) {
    return null;
  }
}

function encrypt(plain) {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', KEY, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
}

// ═══════════════════════════════════════════
// GMAIL
// ═══════════════════════════════════════════
function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

// ═══════════════════════════════════════════
// MIME BUILDER
// ═══════════════════════════════════════════
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
// SENDER PICK
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
// SEND
// ═══════════════════════════════════════════
async function sendOne(recipient) {
  const campaign = recipient.campaign;
  const contact = recipient.contact;

  // Suppression
  const sup = await prisma.suppressionList.findUnique({ where: { email: contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    state.suppressed++;
    return;
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipient.id },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // Pick sender
  const sender = await pickSender(campaign.batchLimit ?? 1);
  if (!sender) {
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'QUEUED' },
    });
    throw new Error('No sender available');
  }

  // Build
  const data = {
    name: contact.name || '',
    email: contact.email,
    company: contact.company || '',
    city: contact.city || '',
    phone: contact.phone || '',
  };
  const finalSubject = formatSubject(campaign.subject, data);
  let html = renderTemplate(campaign.html, data);

  // Pixel
  const pixel = `<img src="${process.env.APP_URL}/api/track/open/${recipient.id}" width="1" height="1" style="display:none" alt="" />`;
  html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

  // Send
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
  const raw = buildMime({
    from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
    to: contact.email,
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

  await prisma.senderAccount.update({
    where: { id: sender.id },
    data: {
      sentToday: { increment: 1 },
      batchCount: { increment: 1 },
      lastSuccessAt: new Date(),
    },
  });

  // Refresh tokens if updated
  if (access && refresh) {
    await prisma.senderAccount.update({
      where: { id: sender.id },
      data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
    }).catch(() => {});
  }

  state.sent++;
  console.log(`✅ [${sender.email}] → ${contact.email} | "${finalSubject}"`);
}

// ═══════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════
async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(' 🤖 EMAIL BOT STARTED');
  console.log('═══════════════════════════════════════════');
  console.log(`  Batch size:   ${BATCH_SIZE}`);
  console.log(`  Delay:        ${DELAY_MS}ms`);
  console.log(`  Max runtime:  ${MAX_RUNTIME_SEC}s`);
  console.log(`  Started:      ${new Date().toISOString()}`);
  console.log('');

  try {
    // Fetch queued (approved only if approval gate enabled)
    const recipients = await prisma.campaignRecipient.findMany({
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
      include: { contact: true, campaign: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recipients.length === 0) {
      const remaining = await prisma.campaignRecipient.count({
        where: {
          status: 'QUEUED',
          campaign: { status: 'RUNNING' },
        },
      });
      console.log(`💤 No queued recipients. Remaining: ${remaining}`);
      await prisma.$disconnect();
      process.exit(0);
    }

    console.log(`📬 Processing ${recipients.length} recipients...`);
    console.log('');

    for (let i = 0; i < recipients.length; i++) {
      // Runtime limit — exit gracefully
      const elapsed = (Date.now() - state.started) / 1000;
      if (elapsed > MAX_RUNTIME_SEC) {
        console.log(`⏱️  Runtime limit (${MAX_RUNTIME_SEC}s) reached. Exiting...`);
        break;
      }

      try {
        await sendOne(recipients[i]);
      } catch (err) {
        const msg = err?.message || 'unknown';
        state.failed++;
        state.errors.push(msg.slice(0, 100));
        console.log(`❌ Failed: ${msg.slice(0, 100)}`);

        // Rate limit → break early
        if (/rate|quota|429/i.test(msg)) {
          console.log('⚠️  Rate limit — stopping early');
          break;
        }
      }

      // Delay between emails
      if (i < recipients.length - 1 && DELAY_MS > 0) {
        await new Promise(r => setTimeout(r, DELAY_MS));
      }
    }

    // Update campaign counters accurately
    const campaignIds = [...new Set(recipients.map(r => r.campaignId))];
    for (const cid of campaignIds) {
      const [sent, total] = await Promise.all([
        prisma.campaignRecipient.count({ where: { campaignId: cid, status: 'SENT' } }),
        prisma.campaignRecipient.count({ where: { campaignId: cid } }),
      ]);
      await prisma.campaign.update({
        where: { id: cid },
        data: { sentCount: sent, totalCount: total },
      }).catch(() => {});

      // Auto-complete if done
      const remaining = await prisma.campaignRecipient.count({
        where: { campaignId: cid, status: { in: ['QUEUED', 'PROCESSING'] } },
      });
      if (remaining === 0) {
        await prisma.campaign.update({
          where: { id: cid },
          data: { status: 'COMPLETED', completedAt: new Date() },
        }).catch(() => {});
      }
    }

    console.log('');
    console.log('═══════════════════════════════════════════');
    console.log(' 📊 RESULTS');
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

main().catch(e => {
  console.error('Unhandled:', e.message);
  process.exit(1);
});
