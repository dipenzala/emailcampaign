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

export async function GET() { return handle(); }
export async function POST() { return handle(); }

async function handle() {
  const results: any = { ok: true, processed: 0, sent: 0, failed: 0, remaining: 0, errors: [] };

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true, campaign: true },
      take: 5,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      return NextResponse.json({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

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
          unsubscribeUrl: `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`,
        });

        const res = await gmail.users.messages.send({
          userId: 'me',
          requestBody: { raw: Buffer.from(raw).toString('base64url') },
        });

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'SENT', senderAccountId: sender.id, providerMessageId: res.data.id, sentAt: new Date() },
        });
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });
        await markSenderUsed(sender.id);
        results.sent++;
      } catch (err: any) {
        results.failed++;
        results.errors.push(err?.message?.slice(0, 100));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    return NextResponse.json(results);
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message, ...results }, 500);
  }
}
