import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_BATCH = 10;

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixel = `<img src="${appUrl}/api/track/open/${recipientId}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) return html.replace(/<\/body>/i, `${pixel}</body>`);
  return html + pixel;
}

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
    to, subject, html, text, unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  try {
    if (res.data.id) {
      await gmail.users.messages.modify({
        userId: 'me',
        id: res.data.id,
        requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
      });
    }
  } catch {}

  return { id: res.data.id, access, refresh };
}

export async function GET(req: Request) {
  const t0 = Date.now();

  // Optional security: verify Vercel cron secret
  const url = new URL(req.url);
  const authHeader = req.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  // If CRON_SECRET is set, verify it (but allow without for now)
  if (cronSecret && authHeader !== `Bearer ${cronSecret}` && !url.searchParams.has('manual')) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const results: any = {
    ok: true,
    ts: new Date().toISOString(),
    processed: 0,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    remaining: 0,
    errors: [] as string[],
  };

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true, campaign: true },
      take: MAX_BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      return json({ ...results, message: 'No queued recipients', elapsed: Date.now() - t0 });
    }

    console.log('[cron] Processing', recips.length, 'recipients');

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        const sup = await prisma.suppressionList.findUnique({
          where: { email: contact.email },
        });
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

        const sender = await pickNextSenderStrict({
          batchLimit: campaign.batchLimit ?? 1,
        });

        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        let html = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });
        html = injectTrackingPixel(html, r.id, process.env.APP_URL || '');

        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender, contact.email, campaign.subject, html, htmlToText(html), unsubUrl
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
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);

        if (isBounce) {
          await prisma.suppressionList.upsert({
            where: { email: r.contact.email },
            create: { email: r.contact.email, reason: 'BOUNCED' },
            update: {},
          }).catch(() => {});
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg.slice(0, 200) },
          });
          results.bounced++;
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED', errorMessage: msg.slice(0, 200) },
          });
          results.failed++;
        }

        results.errors.push(msg.slice(0, 100));
      }
    }

    const remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.remaining = remaining;
    results.elapsed = Date.now() - t0;

    return json(results);
  } catch (err: any) {
    return json({ ok: false, error: err?.message || 'Server error' }, 500);
  }
}
