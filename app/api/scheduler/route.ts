import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * SELF-LOOPING SENDER
 * ---------
 * This endpoint sends as many emails as possible within ~50 seconds.
 * Frontend calls it in a loop (or via external cron).
 */
export async function POST(req: Request) {
  const t0 = Date.now();
  const start = Date.now();
  const MAX_RUNTIME = 50_000; // 50 sec

  const stats = { sent: 0, failed: 0, suppressed: 0, lastError: '' };

  try {
    while (Date.now() - start < MAX_RUNTIME) {
      // Pick ONE queued recipient atomically
      const claimed: any[] = await prisma.$queryRawUnsafe(`
        WITH c AS (
          SELECT id FROM "CampaignRecipient"
          WHERE status = 'QUEUED'
            AND "campaignId" IN (
              SELECT id FROM "Campaign" WHERE status = 'RUNNING'
            )
          ORDER BY "queuedAt" ASC
          LIMIT 1
          FOR UPDATE SKIP LOCKED
        )
        UPDATE "CampaignRecipient" cr
        SET status = 'PROCESSING', "attemptCount" = cr."attemptCount" + 1
        FROM c WHERE cr.id = c.id
        RETURNING cr.id, cr."campaignId"
      `);

      if (claimed.length === 0) break;

      const recipientId = claimed[0].id;
      const campaignId = claimed[0].campaignId;

      try {
        const r = await prisma.campaignRecipient.findUnique({
          where: { id: recipientId },
          include: { contact: true },
        });
        if (!r) continue;

        const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
        if (!campaign || campaign.status !== 'RUNNING') continue;

        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
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
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
            data: { status: 'QUEUED' },
          });
          stats.lastError = 'No sender available';
          break;
        }

        // Build
        const data = {
          name: r.contact.name || '',
          email: r.contact.email,
          company: r.contact.company || '',
          city: r.contact.city || '',
          phone: r.contact.phone || '',
        };
        const finalSubject = formatSubject(campaign.subject, data);
        let html = renderTemplate(campaign.html, data);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${recipientId}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        // Send
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
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

        try {
          if (res.data.id) {
            await gmail.users.messages.modify({
              userId: 'me',
              id: res.data.id,
              requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
            });
          }
        } catch {}

        // Update
        await prisma.campaignRecipient.update({
          where: { id: recipientId },
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

        // Small delay — rate-limit friendly
        await new Promise(res => setTimeout(res, 800));
      } catch (err: any) {
        stats.failed++;
        stats.lastError = (err.message || '').slice(0, 100);

        await prisma.campaignRecipient.update({
          where: { id: recipientId },
          data: { status: 'FAILED', errorMessage: (err.message || '').slice(0, 200) },
        }).catch(() => {});

        if (/rate|quota|429/i.test(err.message || '')) {
          console.log('⚠️ Rate limit — exiting');
          break;
        }
      }
    }

    // Recalc running campaigns
    const runningCampaigns = await prisma.campaign.findMany({ where: { status: 'RUNNING' } });
    for (const c of runningCampaigns) {
      const [sent, total, queued] = await Promise.all([
        prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'SENT' } }),
        prisma.campaignRecipient.count({ where: { campaignId: c.id } }),
        prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'QUEUED' } }),
      ]);
      const update: any = { sentCount: sent, totalCount: total };
      if (queued === 0) {
        update.status = 'COMPLETED';
        update.completedAt = new Date();
      }
      await prisma.campaign.update({ where: { id: c.id }, data: update }).catch(() => {});
    }

    return NextResponse.json({
      ok: true,
      ...stats,
      elapsed: Date.now() - t0,
      stillQueued: await prisma.campaignRecipient.count({ where: { status: 'QUEUED' } }),
    });
  } catch (err: any) {
    console.error('[scheduler] FATAL:', err);
    return NextResponse.json({ ok: false, error: err.message, ...stats }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({ ok: true, message: 'Use POST to trigger send loop' });
}
