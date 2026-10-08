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
