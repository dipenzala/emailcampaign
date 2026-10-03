import 'dotenv/config';
import { Worker, Job } from 'bullmq';
import { prisma } from '../lib/prisma';
import { redis } from '../lib/redis';
import { SEND_QUEUE, QUEUE_PREFIX } from '../lib/queue';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSender, markSenderUsed } from '../lib/sender-rotation';
import { effectiveLimit } from '../lib/warmup';
import { handleBounce } from '../lib/bounce-handler';

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });
  const raw = buildMime({ from: `${sender.displayName ?? sender.email} <${sender.email}>`, to, subject, html, text, unsubscribeUrl: unsubUrl });
  const res = await gmail.users.messages.send({ userId: 'me', requestBody: { raw: Buffer.from(raw).toString('base64url') } });
  return { id: res.data.id, access, refresh };
}

const worker = new Worker(SEND_QUEUE, async (job: Job) => {
  const { campaignId, recipientId } = job.data;
  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) throw new Error('Campaign missing');
  if (campaign.status === 'PAUSED') throw new Error('PAUSED');
  if (campaign.status === 'STOPPED') return { skipped: true };

  const r = await prisma.campaignRecipient.findUnique({ where: { id: recipientId }, include: { contact: true } });
  if (!r) return;
  if (r.status === 'SENT' || r.status === 'DELIVERED') return { alreadySent: true };

  await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 } });

  const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason } });
    await prisma.campaign.update({ where: { id: campaignId }, data: { suppressedCount: { increment: 1 } } });
    return;
  }

  const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
  if (!sender) throw new Error('No authorized sender available');

  const cap = effectiveLimit({ warmupEnabled: sender.warmupEnabled, warmupDay: sender.warmupDay, dailyLimit: sender.dailyLimit });
  if (sender.sentToday >= cap) {
    console.log(`⏸️  Warm-up cap reached for ${sender.email} (${sender.sentToday}/${cap})`);
    throw new Error('Sender warm-up limit reached');
  }

  console.log(`📤 [ROTATION] ${sender.email} (sentToday=${sender.sentToday}, batch=${sender.batchCount}/${campaign.batchLimit}, warmupDay=${sender.warmupDay})`);

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
  const personalizedHtml = renderTemplate(campaign.html, {
    name: r.contact.name ?? '', email: r.contact.email, company: r.contact.company ?? '', city: r.contact.city ?? '', phone: r.contact.phone ?? '',
  });
  const text = htmlToText(personalizedHtml);

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(sender, r.contact.email, campaign.subject, personalizedHtml, text, unsubUrl);

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SENT', senderAccountId: sender.id, providerMessageId, sentAt: new Date(), errorCode: null, errorMessage: null },
    });
    await prisma.campaign.update({ where: { id: campaignId }, data: { sentCount: { increment: 1 } } });
    await markSenderUsed(sender.id);

    if (access && refresh) {
      await prisma.senderAccount.update({ where: { id: sender.id }, data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) } });
    }

    const remaining = await prisma.campaignRecipient.count({ where: { campaignId, status: { in: ['QUEUED','PROCESSING'] } } });
    if (remaining === 0) {
      await prisma.campaign.update({ where: { id: campaignId }, data: { status: 'COMPLETED', completedAt: new Date() } });
    }
    return { ok: true, sender: sender.email };
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);
    const retryable = !isBounce && (/rate|quota|429|500|502|503|timeout|ECONN/i.test(msg) || code === 429);

    if (isBounce) {
      await handleBounce({ email: r.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' } });
      await prisma.campaign.update({ where: { id: campaignId }, data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } } });
      return { bounced: true };
    }

    if (!retryable) {
      await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() } });
      await prisma.campaign.update({ where: { id: campaignId }, data: { failedCount: { increment: 1 } } });
      return { failed: true };
    }
    throw err;
  }
}, {
  connection: redis,
  prefix: QUEUE_PREFIX,
  concurrency: 4,
  limiter: { max: 10, duration: 1000 },
});

worker.on('failed', async (job, err) => {
  if (job && err.message === 'PAUSED') await job.retry().catch(() => {});
});
worker.on('completed', j => console.log('✅', j.id));
worker.on('error', e => console.error('worker error', e));

console.log('🚀 Sender worker running (rotation + warmup + anti-spam)…');
