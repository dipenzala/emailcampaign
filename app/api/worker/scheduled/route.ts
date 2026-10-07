import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';
import { autoResetIfNewDay } from '@/lib/daily-reset';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

export async function GET() { return handle(); }
export async function POST() { return handle(); }

async function handle() {
  const t0 = Date.now();
  const now = new Date();
  const results: any = {
    ok: true,
    now: now.toISOString(),
    localTime: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
    processed: 0, sent: 0, failed: 0, skipped: 0,
    activeCampaigns: [] as string[],
    inactiveCampaigns: [] as string[],
    elapsed: 0,
  };

  try {
    // ⚡ Daily reset
    try {
      await autoResetIfNewDay();
    } catch {}

    // Get all RUNNING scheduled campaigns
    const scheduledCampaigns = await prisma.campaign.findMany({
      where: {
        campaignType: 'scheduled',
        status: 'RUNNING',
      },
    });

    if (scheduledCampaigns.length === 0) {
      results.message = 'No active scheduled campaigns';
      results.elapsed = Date.now() - t0;
      return j(results);
    }

    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    for (const campaign of scheduledCampaigns) {
      const startMinutes = campaign.scheduleStartHour * 60 + campaign.scheduleStartMinute;
      const endMinutes = startMinutes + campaign.scheduleDurationMinutes;

      // Check if in active window
      const isActive = currentMinutes >= startMinutes && currentMinutes < endMinutes;

      if (!isActive) {
        results.inactiveCampaigns.push(campaign.name);
        continue;
      }

      results.activeCampaigns.push(campaign.name);

      // Update lastActiveDate
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { lastActiveDate: now },
      });

      // Fetch queued emails for this campaign (small batch)
      const recips = await prisma.campaignRecipient.findMany({
        where: {
          campaignId: campaign.id,
          status: 'QUEUED',
        },
        include: { contact: true },
        take: 20,
        orderBy: { queuedAt: 'asc' },
      });

      if (recips.length === 0) {
        // Check if campaign is complete
        const remaining = await prisma.campaignRecipient.count({
          where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
        });
        if (remaining === 0) {
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { status: 'COMPLETED', completedAt: new Date() },
          });
          console.log(`🎉 [scheduled] Campaign "${campaign.name}" COMPLETED`);
        }
        continue;
      }

      // Process each
      for (const r of recips) {
        results.processed++;
        try {
          const contact = r.contact;

          // Suppression
          const sup = await prisma.suppressionList.findUnique({
            where: { email: contact.email },
          });
          if (sup) {
            await prisma.campaignRecipient.update({
              where: { id: r.id },
              data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
            });
            results.skipped++;
            continue;
          }

          // Pick sender
          const sender = await pickNextSenderStrict({ batchLimit: 1 });
          if (!sender) {
            results.skipped++;
            break;
          }

          // Mark processing
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
          });

          // Build email
          const recipientData = {
            name: contact.name || '',
            email: contact.email,
            company: contact.company || '',
            city: contact.city || '',
            phone: contact.phone || '',
          };

          const finalSubject = formatSubject(campaign.subject, recipientData);
          let html = renderTemplate(campaign.html, recipientData);

          // Pixel
          const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
          html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

          // Send via Gmail
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
            unsubscribeUrl: unsubUrl,
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
          const [accSent, accTotal] = await Promise.all([
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id, status: 'SENT' } }),
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id } }),
        ]);
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: accSent, totalCount: accTotal },
        });
          await markSenderUsed(sender.id);

          results.sent++;
          console.log(`[scheduled] ✅ ${contact.email} (${contact.company || 'no company'})`);
        } catch (err: any) {
          const msg = err?.message ?? 'failed';
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
            }).catch(() => {});
          } else {
            await prisma.campaignRecipient.update({
              where: { id: r.id },
              data: {
                status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
                errorMessage: msg.slice(0, 200),
              },
            }).catch(() => {});
          }
          results.failed++;
        }

        // Time check — if we're near end of window, stop
        const nowCheck = new Date();
        const checkMinutes = nowCheck.getHours() * 60 + nowCheck.getMinutes();
        if (checkMinutes >= endMinutes) {
          console.log(`[scheduled] Window ended for "${campaign.name}"`);
          break;
        }
      }
    }

    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    console.error('[scheduled] FATAL:', err);
    return j({ ok: false, error: err?.message, ...results }, 500);
  }
}
