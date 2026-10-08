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
 * Emergency single-email send API — bypasses worker entirely.
 * Sends next N queued emails IMMEDIATELY (synchronous).
 * Use this when worker/bot are broken.
 */
export async function POST(req: Request, { params }: { params: { id: string } }) {
  try {
    const body = await req.json().catch(() => ({}));
    const BATCH = Math.min(20, Math.max(1, parseInt(body.batchSize || '5', 10)));

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'Campaign not found' }, { status: 404 });
    }

    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, sent: 0, message: 'No queued recipients' });
    }

    let sent = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const r of recips) {
      try {
        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          continue;
        }

        // Pick sender
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
          errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Build email
        const data = {
          name: r.contact.name || '',
          email: r.contact.email,
          company: r.contact.company || '',
          city: r.contact.city || '',
          phone: r.contact.phone || '',
        };

        const finalSubject = formatSubject(campaign.subject, data);
        let html = renderTemplate(campaign.html, data);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
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

        // Update
        await prisma.campaignRecipient.update({
          where: { id: r.id },
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

        sent++;
        console.log(`✅ SENT: ${r.contact.email} via ${sender.email}`);
      } catch (err: any) {
        failed++;
        const msg = err.message || 'unknown';
        errors.push(msg.slice(0, 150));
        console.error(`❌ Failed: ${r.contact.email}:`, msg);

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'FAILED', errorMessage: msg.slice(0, 200) },
        }).catch(() => {});
      }
    }

    // Recalc campaign counters
    const [accSent, accTotal] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId: params.id, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId: params.id } }),
    ]);
    await prisma.campaign.update({
      where: { id: params.id },
      data: { sentCount: accSent, totalCount: accTotal },
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      sent,
      failed,
      errors: errors.slice(0, 5),
    });
  } catch (err: any) {
    console.error('[send-one] FATAL:', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
