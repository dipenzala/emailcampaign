import { NextResponse } from 'next/server';
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

export async function GET(req: Request) { return handle(req); }
export async function POST(req: Request) { return handle(req); }

async function handle(req: Request) {
  const t0 = Date.now();
  const results: any = {
    ok: true, processed: 0, sent: 0, failed: 0, bounced: 0,
    suppressed: 0, remaining: 0, errors: [] as string[], elapsed: 0,
  };

  try {
    const url = new URL(req.url);
    const BATCH = Math.min(50, Math.max(1, parseInt(url.searchParams.get('batch') || '5', 10) || 5));
    results.batchSize = BATCH;

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

    // Fetch queued with contact
    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true, campaign: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      results.elapsed = Date.now() - t0;
      return j({ ...results, message: 'No queued recipients' });
    }

    // Process each
    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

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

        // Pick sender
        const sender = await pickNextSenderStrict({ batchLimit: campaign.batchLimit ?? 1 });
        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // ═══════════════════════════════════════════
        // BUILD EMAIL with formatSubject
        // ═══════════════════════════════════════════
        const recipientData = {
          name: contact.name || '',
          email: contact.email,
          company: contact.company || '',
          city: contact.city || '',
          phone: contact.phone || '',
        };

        // Format subject
        const finalSubject = formatSubject(campaign.subject, recipientData);

        // Render HTML
        let html = renderTemplate(campaign.html, recipientData);

        // Tracking pixel
        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        // Unsubscribe URL
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

        console.log(`[bulk] To: ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

        // Send
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: contact.email,
          subject: finalSubject,  // ← formatted subject
          html,
          text: htmlToText(html),
          unsubscribeUrl: unsubUrl,
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
            errorCode: null,
            errorMessage: null,
          },
        });
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });
        await markSenderUsed(sender.id);

        results.sent++;
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
          }).catch(() => {});
          results.bounced++;
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: {
              status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
              errorMessage: msg.slice(0, 200),
            },
          }).catch(() => {});
          results.failed++;
        }
        results.errors.push(msg.slice(0, 150));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    console.error('[bulk] FATAL:', err);
    return j({ ok: false, error: err?.message || 'Server error', ...results }, 500);
  }
}
