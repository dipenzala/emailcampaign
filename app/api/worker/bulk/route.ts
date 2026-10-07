import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

export async function GET(req: Request) {
  const t0 = Date.now();
  const results: any = {
    ok: true,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    processed: 0,
    remaining: 0,
    errors: [],
    elapsed: 0,
  };

  try {
    const url = new URL(req.url);
    const batchSize = Math.min(50, Math.max(1, parseInt(url.searchParams.get('batch') || '5', 10)));

    // Dynamic imports — no top-level crash
    const { prisma } = await import('@/lib/prisma');
    const { decrypt, encrypt } = await import('@/lib/crypto');
    const { oauthClient } = await import('@/lib/gmail');
    const { google } = await import('googleapis');
    const { buildMime, htmlToText } = await import('@/lib/mime');
    const { renderTemplate } = await import('@/lib/personalization');
    const { pickNextSenderStrict, markSenderUsed } = await import('@/lib/sender-rotation');

    console.log('[bulk] START batch=' + batchSize);

    // Self-heal
    await prisma.campaignRecipient.updateMany({
      where: { status: 'PROCESSING' },
      data: { status: 'QUEUED', attemptCount: 0 },
    }).catch(() => {});

    await prisma.campaign.updateMany({
      where: {
        status: { in: ['PAUSED', 'STOPPED'] },
        recipients: { some: { status: 'QUEUED' } },
      },
      data: { status: 'RUNNING' },
    }).catch(() => {});

    // Fetch queued
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true, campaign: true },
      take: batchSize,
      orderBy: { queuedAt: 'asc' },
    });

    console.log('[bulk] Found', recips.length, 'queued');

    if (recips.length === 0) {
      const remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      results.remaining = remaining;
      results.elapsed = Date.now() - t0;
      return json({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
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
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { suppressedCount: { increment: 1 } },
          });
          results.suppressed++;
          continue;
        }

        // Pick sender
        const sender = await pickNextSenderStrict({
          batchLimit: campaign.batchLimit ?? 1,
        });

        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Build email
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        let html = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });

        // Inject tracking pixel
        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        if (/<\/body>/i.test(html)) {
          html = html.replace(/<\/body>/i, `${pixel}</body>`);
        } else {
          html = html + pixel;
        }

        // Send via Gmail
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: contact.email,
          subject: campaign.subject,
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

        // Update recipient
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

        // Update campaign
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });

        // Update sender
        await markSenderUsed(sender.id);

        results.sent++;
        console.log('[bulk] SENT', contact.email);
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
            data: {
              status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
              errorMessage: msg.slice(0, 200),
            },
          });
          results.failed++;
        }
        results.errors.push(msg.slice(0, 100));
        console.error('[bulk] FAIL', r.contact.email, msg);
      }
    }

    // Check complete
    const remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.remaining = remaining;
    results.elapsed = Date.now() - t0;

    return json(results);
  } catch (err: any) {
    console.error('[bulk] FATAL:', err);
    return json({
      ok: false,
      error: err?.message || 'Server error',
      stack: err?.stack?.slice(0, 300),
      ...results,
    }, 500);
  }
}

export async function POST(req: Request) {
  return GET(req);
}
