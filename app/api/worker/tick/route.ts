import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { pickNextSender, markSenderUsed } from '@/lib/sender-rotation';
import { effectiveLimit } from '@/lib/warmup';
import { handleBounce } from '@/lib/bounce-handler';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';
export const maxDuration = 60;

const BATCH_SIZE = 5;

async function sendViaGmail(
  sender: any,
  to: string,
  subject: string,
  html: string,
  text: string,
  unsubUrl?: string
) {
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

export async function GET() {
  return tick();
}

export async function POST() {
  return tick();
}

async function tick() {
  const results = {
    processed: 0,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    errors: [] as string[],
  };

  try {
    // Fetch QUEUED recipients from RUNNING campaigns
    const recipients = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: {
        contact: true,
        campaign: true,
      },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recipients.length === 0) {
      return NextResponse.json({
        ok: true,
        ...results,
        message: 'No queued recipients',
      });
    }

    for (const r of recipients) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { suppressedCount: { increment: 1 } },
          });
          results.suppressed++;
          continue;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Pick sender
        const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
        if (!sender) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED' },
          });
          results.errors.push('No sender available');
          break;
        }

        // Warm-up check
        const cap = effectiveLimit({
          warmupEnabled: sender.warmupEnabled,
          warmupDay: sender.warmupDay,
          dailyLimit: sender.dailyLimit,
        });
        if (sender.sentToday >= cap) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED' },
          });
          results.errors.push(`Warm-up cap reached for ${sender.email} (${sender.sentToday}/${cap})`);
          break;
        }

        // Build email
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        const personalizedHtml = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });
        const text = htmlToText(personalizedHtml);

        // Send
        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender,
          contact.email,
          campaign.subject,
          personalizedHtml,
          text,
          unsubUrl
        );

        await prisma.campaignRecipient.update({
          where: { id: r.id },
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
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });

        await markSenderUsed(sender.id);

        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          });
        }

        results.sent++;

        // Check campaign complete
        const remaining = await prisma.campaignRecipient.count({
          where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
        });
        if (remaining === 0) {
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { status: 'COMPLETED', completedAt: new Date() },
          });
        }
      } catch (err: any) {
        const msg = err?.message ?? 'Send failed';
        const code = err?.code ?? err?.response?.status ?? 'ERROR';
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);

        if (isBounce) {
          await handleBounce({ email: r.contact.email, senderAccountId: null, bounceType: 'HARD' });
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' },
          });
          await prisma.campaign.update({
            where: { id: r.campaignId },
            data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } },
          });
          results.bounced++;
        } else if (r.attemptCount < 3) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED', errorMessage: msg },
          });
          results.errors.push(msg);
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() },
          });
          await prisma.campaign.update({
            where: { id: r.campaignId },
            data: { failedCount: { increment: 1 } },
          });
          results.failed++;
        }
      }
    }

    return NextResponse.json({ ok: true, ...results });
  } catch (err: any) {
    console.error('[worker/tick]', err);
    return NextResponse.json(
      { ok: false, error: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
