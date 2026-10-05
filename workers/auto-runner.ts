// ═══════════════════════════════════════════
// NEVER-STOP WORKER
// Chalti rahegi 24/7 — crash ho to restart,
// cap hit ho to reset, kuch bhi ho to recover
// ═══════════════════════════════════════════

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { google } from 'googleapis';
import crypto from 'crypto';

const prisma = new PrismaClient();

// ═══════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════
const POLL_MS = 2000;              // Poll every 2 seconds
const BATCH_SIZE = 1;              // Strict one-by-one
const MAX_DAILY = 350;             // Per sender
const RESET_BATCH_AFTER = 350;     // Batch reset when all capped
const IDLE_LOG_EVERY_MS = 60000;   // Log "idle" every 60s

// ═══════════════════════════════════════════
// CRYPTO
// ═══════════════════════════════════════════
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');

function decrypt(payload: string): string {
  try {
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const data = buf.subarray(28);
    const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
    d.setAuthTag(tag);
    return Buffer.concat([d.update(data), d.final()]).toString('utf8');
  } catch {
    return '';
  }
}

function encrypt(plain: string): string {
  try {
    const iv = crypto.randomBytes(12);
    const c = crypto.createCipheriv('aes-256-gcm', KEY, iv);
    const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
    return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
  } catch {
    return '';
  }
}

// ═══════════════════════════════════════════
// EMAIL HELPERS
// ═══════════════════════════════════════════
function htmlToText(h: string): string {
  return h.replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]+>/g, '')
    .replace(/\n{3,}/g, '\n\n').trim();
}

function renderTemplate(html: string, data: Record<string, any>): string {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_: any, k: string, def: string) => {
    const v = data[k];
    return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
  });
}

function buildMime(o: any): string {
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

function injectPixel(html: string, recipientId: string, appUrl: string): string {
  const url = `${appUrl}/api/track/open/${recipientId}`;
  const pixel = `<img src="${url}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) return html.replace(/<\/body>/i, `${pixel}</body>`);
  return html + pixel;
}

// ═══════════════════════════════════════════
// SENDER PICKER — NEVER GETS STUCK
// ═══════════════════════════════════════════
async function pickSender(batchLimit: number) {
  const senders = await prisma.senderAccount.findMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  if (senders.length === 0) return null;

  // Pass 1: pick first with room
  for (const s of senders) {
    const cap = s.dailyLimit || MAX_DAILY;
    if (s.sentToday >= cap) continue;
    if (s.batchCount < batchLimit) return s;
  }

  // Pass 2: everyone batch-full → reset ALL batches and pick first under cap
  await prisma.senderAccount.updateMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    data: { batchCount: 0 },
  });
  console.log('   🔄 All batches reset — new cycle starts');

  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    const cap = s.dailyLimit || MAX_DAILY;
    if (s.sentToday < cap) return s;
  }

  // Truly all capped — return null but worker keeps running
  return null;
}

// ═══════════════════════════════════════════
// SEND ONE EMAIL
// ═══════════════════════════════════════════
async function sendOne(recipient: any): Promise<'sent' | 'failed' | 'skipped' | 'retry'> {
  const campaign = await prisma.campaign.findUnique({ where: { id: recipient.campaignId } });
  if (!campaign || campaign.status !== 'RUNNING') return 'skipped';

  // Suppression check
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
    console.log(`   ⏭️  SUPPRESSED: ${recipient.contact.email}`);
    return 'skipped';
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipient.id },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // Pick sender
  const batchLimit = campaign.batchLimit || MAX_DAILY;
  const sender = await pickSender(batchLimit);

  if (!sender) {
    // Put back in queue — worker keeps polling
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'QUEUED' },
    });
    return 'retry';
  }

  // Build email
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken || '');

  const oauth2 = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
  oauth2.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: oauth2 });

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  let html = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  html = injectPixel(html, recipient.id, process.env.APP_URL || '');

  const senderName = sender.displayName || 'Startup Team';
  const raw = buildMime({
    from: `${senderName} <${sender.email}>`,
    to: recipient.contact.email,
    subject: campaign.subject,
    html,
    text: htmlToText(html),
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

    console.log(`   ✅ SENT [${sender.email}] → ${recipient.contact.email} (batch: ${sender.batchCount + 1}/${batchLimit})`);

    // Check complete
    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('   🎉 CAMPAIGN COMPLETED');
    }

    return 'sent';
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);
    const isPerm = /insufficient|permission|invalid_grant|unauthorized/i.test(msg);

    if (isBounce || isPerm) {
      await prisma.suppressionList.upsert({
        where: { email: recipient.contact.email },
        create: { email: recipient.contact.email, reason: isBounce ? 'BOUNCED' : 'MANUAL_BLOCK' },
        update: {},
      }).catch(() => {});

      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: {
          status: isBounce ? 'BOUNCED' : 'SUPPRESSED',
          errorCode: isBounce ? 'BOUNCED' : 'AUTO_SUPPRESSED',
          errorMessage: msg.slice(0, 200),
          failedAt: new Date(),
        },
      });

      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { failedCount: { increment: 1 } },
      });

      console.log(`   ⛔ ${isBounce ? 'BOUNCED' : 'SUPPRESSED'} ${recipient.contact.email}`);
      return 'failed';
    }

    // Retryable — put back
    if (recipient.attemptCount < 3) {
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'QUEUED', errorMessage: msg.slice(0, 200) },
      });
    } else {
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'FAILED', errorCode: String(code), errorMessage: msg.slice(0, 200), failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { failedCount: { increment: 1 } },
      });
    }
    console.log(`   ❌ RETRY ${recipient.contact.email}: ${msg.slice(0, 60)}`);
    return 'retry';
  }
}

// ═══════════════════════════════════════════
// DAILY RESET — auto at midnight
// ═══════════════════════════════════════════
async function dailyReset() {
  const now = new Date();
  if (now.getHours() === 0 && now.getMinutes() < 5) {
    const r = await prisma.senderAccount.updateMany({
      data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
    });
    if (r.count > 0) console.log(`   🌅 Daily reset: ${r.count} senders`);
  }
}

// ═══════════════════════════════════════════
// MAIN POLL LOOP — NEVER STOPS
// ═══════════════════════════════════════════
let isProcessing = false;
let lastIdleLog = 0;
let totalProcessed = 0;
let consecutiveErrors = 0;

async function poll() {
  if (isProcessing) return;
  isProcessing = true;

  try {
    await dailyReset();

    // Get next QUEUED recipient
    const recipients = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recipients.length === 0) {
      // Idle — no emails to send
      const now = Date.now();
      if (now - lastIdleLog > IDLE_LOG_EVERY_MS) {
        const queued = await prisma.campaignRecipient.count({ where: { status: 'QUEUED' } });
        const running = await prisma.campaign.count({ where: { status: 'RUNNING' } });
        console.log(`   💤 Idle — queued: ${queued}, running campaigns: ${running}`);
        lastIdleLog = now;
      }
      isProcessing = false;
      return;
    }

    const result = await sendOne(recipients[0]);
    if (result === 'sent') totalProcessed++;
    if (result === 'retry' || result === 'failed') consecutiveErrors++;
    else consecutiveErrors = 0;

    // Too many errors → short pause but keep running
    if (consecutiveErrors > 20) {
      console.log(`   ⚠️  ${consecutiveErrors} consecutive errors — cooling down 30s`);
      await new Promise(r => setTimeout(r, 30000));
      consecutiveErrors = 0;
    }
  } catch (e: any) {
    console.error('   ❌ Poll error:', e.message);
  } finally {
    isProcessing = false;
  }
}

// ═══════════════════════════════════════════
// AUTO-RECOVERY — unhandled errors
// ═══════════════════════════════════════════
process.on('uncaughtException', (err) => {
  console.error('💥 Uncaught:', err.message);
  // Don't exit — keep running
});

process.on('unhandledRejection', (err: any) => {
  console.error('💥 Unhandled rejection:', err?.message || err);
  // Don't exit
});

process.on('SIGINT', async () => {
  console.log('\n🛑 Stopping worker...');
  await prisma.$disconnect();
  process.exit(0);
});

// ═══════════════════════════════════════════
// START
// ═══════════════════════════════════════════
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🚀 NEVER-STOP WORKER');
console.log('═══════════════════════════════════════════');
console.log('   Poll:        ' + (POLL_MS / 1000) + 's');
console.log('   Batch:       ' + BATCH_SIZE + ' email per sender');
console.log('   Max daily:   ' + MAX_DAILY + ' per sender');
console.log('   Auto-reset:  Yes (midnight + batch)');
console.log('   Auto-recover: Yes (errors, crash)');
console.log('');
console.log('🎯 Running 24/7...');
console.log('');

poll();
setInterval(poll, POLL_MS);

// Keep process alive forever
setInterval(() => {
  // heartbeat
}, 60000);
