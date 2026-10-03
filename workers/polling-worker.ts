import 'dotenv/config';
import { prisma } from '../lib/prisma';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSender, markSenderUsed } from '../lib/sender-rotation';
import { effectiveLimit } from '../lib/warmup';
import { handleBounce } from '../lib/bounce-handler';

const POLL_INTERVAL = 2000; // 2 seconds
const BATCH_SIZE = 5;       // Process 5 at a time

let running = true;
let processing = false;

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to,
    subject,
    html,
    text,
    unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  return { id: res.data.id, access, refresh };
}

async function processOne(recipient: any) {
  const { id: recipientId, campaignId } = recipient;

  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) return false;
  if (campaign.status === 'PAUSED' || campaign.status === 'STOPPED') return false;

  // Suppression check
  const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { suppressedCount: { increment: 1 } },
    });
    return true;
  }

  // Mark as processing
  await prisma.campaignRecipient.update({
    where: { id: recipientId },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // Pick sender
  const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
  if (!sender) {
    console.log('⚠️  No sender available');
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'QUEUED' },
    });
    return false;
  }

  // Warm-up check
  const cap = effectiveLimit({
    warmupEnabled: sender.warmupEnabled,
    warmupDay: sender.warmupDay,
    dailyLimit: sender.dailyLimit,
  });
  if (sender.sentToday >= cap) {
    console.log(`⏸️  Warm-up cap reached: ${sender.email} (${sender.sentToday}/${cap})`);
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'QUEUED' },
    });
    return false;
  }

  console.log(`📤 [${sender.email}] → ${recipient.contact.email}`);

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  const personalizedHtml = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  const text = htmlToText(personalizedHtml);

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(
      sender,
      recipient.contact.email,
      campaign.subject,
      personalizedHtml,
      text,
      unsubUrl
    );

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId,
        sentAt: new Date(),
        errorCode: null,
        errorMessage: null,
      },
    });

    await prisma.campaign.update({
      where: { id: campaignId },
      data: { sentCount: { increment: 1 } },
    });

    await markSenderUsed(sender.id);

    if (access && refresh) {
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
      });
    }

    console.log(`✅ SENT to ${recipient.contact.email}`);

    // Check campaign complete
    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 Campaign completed!');
    }

    return true;
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);

    if (isBounce) {
      await handleBounce({ email: recipient.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } },
      });
      return false;
    }

    // Retryable error — put back in queue
    if (recipient.attemptCount < 3) {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'QUEUED', errorMessage: msg },
      });
    } else {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
    }
    console.log(`❌ Failed ${recipient.contact.email}: ${msg}`);
    return false;
  }
}

async function poll() {
  if (!running) return;
  if (processing) return;
  processing = true;

  try {
    // Get QUEUED recipients from RUNNING campaigns
    const recipients = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recipients.length > 0) {
      console.log(`\n📬 Found ${recipients.length} queued recipient(s)`);
      for (const r of recipients) {
        if (!running) break;
        await processOne(r);
      }
    }
  } catch (e: any) {
    console.error('Poll error:', e.message);
  } finally {
    processing = false;
  }
}

// ==========================================
// START
// ==========================================
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🚀 Polling Worker (BullMQ bypass)');
console.log('═══════════════════════════════════════════');
console.log('   DB:          ' + (process.env.DATABASE_URL || '').slice(0, 40) + '...');
console.log('   Poll every:  ' + (POLL_INTERVAL / 1000) + 's');
console.log('   Batch size:  ' + BATCH_SIZE);
console.log('');
console.log('🎯 Listening for QUEUED recipients...');
console.log('');

// Initial poll
poll();

// Schedule
setInterval(poll, POLL_INTERVAL);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down...');
  running = false;
  await prisma.$disconnect();
  process.exit(0);
});
