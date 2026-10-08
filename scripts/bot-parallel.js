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
