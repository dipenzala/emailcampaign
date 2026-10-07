import { NextResponse } from 'next/server';
import { autoResetIfNewDay } from '@/lib/daily-reset';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

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
  const results: any = { ok: true, processed: 0, sent: 0, failed: 0, remaining: 0, errors: [], elapsed: 0 };

  try {
    // ⚡ DAILY RESET
    try {
      const resetInfo = await autoResetIfNewDay();
      if (resetInfo.reset > 0) results.dailyReset = resetInfo.reset;
    } catch (e: any) {
      console.log('[process] daily-reset error:', e.message);
    }

    // Self-heal
    try {
      const twoMinAgo = new Date(Date.now() - 2 * 60 * 1000);
      await prisma.campaignRecipient.updateMany({
        where: { status: 'PROCESSING', queuedAt: { lt: twoMinAgo } },
        data: { status: 'QUEUED' },
      });
      await prisma.campaign.updateMany({
        where: { status: { in: ['PAUSED', 'STOPPED'] }, recipients: { some: { status: 'QUEUED' } } },
        data: { status: 'RUNNING' },
      });
    } catch {}

    const recips = await prisma.campaignRecipient.findMany({
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
      take: 3,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
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
      });
      results.elapsed = Date.now() - t0;
      return j({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

        const sup = await prisma.suppressionList.findUnique({ where: { email: contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          continue;
        }

        const sender = await pickNextSenderStrict({ batchLimit: campaign.batchLimit ?? 1 });
        if (!sender) { results.errors.push('No sender'); break; }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        const recipientData = {
          name: contact.name || '',
          email: contact.email,
          company: contact.company || '',
          city: contact.city || '',
          phone: contact.phone || '',
        };

        const finalSubject = formatSubject(campaign.subject, recipientData);
        let html = renderTemplate(campaign.html, recipientData);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

        console.log(`[process] ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

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
      } catch (err: any) {
        const msg = err?.message ?? 'failed';
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: {
            status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
            errorMessage: msg.slice(0, 200),
          },
        }).catch(() => {});
        results.failed++;
        results.errors.push(msg.slice(0, 150));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
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
    });
    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    return j({ ok: false, error: err?.message, ...results }, 500);
  }
}
