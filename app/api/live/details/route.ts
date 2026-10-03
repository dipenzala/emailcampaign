import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Return JSON for ALL errors (never HTML)
function jsonError(msg: string, status = 500) {
  return NextResponse.json({ ok: false, error: msg, type: 'error' }, { status });
}

export async function GET(req: Request) {
  try {
    // Auth check
    const cookieStore = cookies();
    const token = cookieStore.get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return jsonError('Unauthorized', 401);
    }

    const url = new URL(req.url);
    const type = url.searchParams.get('type') || '';
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '200'), 500);

    // CAMPAIGNS
    if (type === 'campaigns') {
      const campaigns = await prisma.campaign.findMany({
        orderBy: { createdAt: 'desc' },
        take: limit,
        select: {
          id: true, name: true, subject: true, status: true,
          totalCount: true, sentCount: true, failedCount: true,
          bouncedCount: true, suppressedCount: true,
          createdAt: true,
        },
      });
      return NextResponse.json({ ok: true, type: 'campaigns', items: campaigns });
    }

    // RECIPIENTS BY STATUS
    const statusMap: Record<string, string[]> = {
      sent: ['SENT'],
      pending: ['QUEUED', 'PROCESSING'],
      failed: ['FAILED'],
      bounced: ['BOUNCED'],
      suppressed: ['SUPPRESSED'],
      delivered: ['DELIVERED'],
      queued: ['QUEUED'],
      processing: ['PROCESSING'],
    };

    const statuses = statusMap[type];
    if (!statuses) {
      return jsonError('Unknown type: ' + type, 400);
    }

    const recipients = await prisma.campaignRecipient.findMany({
      where: { status: { in: statuses } },
      orderBy: { queuedAt: 'desc' },
      take: limit,
      include: {
        contact: { select: { email: true, name: true, company: true } },
        campaign: { select: { id: true, name: true } },
      },
    });

    const senderIds = [...new Set(recipients.map(r => r.senderAccountId).filter(Boolean))] as string[];
    const senders = senderIds.length
      ? await prisma.senderAccount.findMany({
          where: { id: { in: senderIds } },
          select: { id: true, email: true },
        })
      : [];
    const senderMap: Record<string, string> = {};
    senders.forEach(s => { senderMap[s.id] = s.email; });

    const items = recipients.map(r => ({
      id: r.id,
      email: r.contact.email,
      name: r.contact.name,
      company: r.contact.company,
      status: r.status,
      sentAt: r.sentAt,
      failedAt: r.failedAt,
      queuedAt: r.queuedAt,
      error: r.errorMessage,
      campaignName: r.campaign.name,
      campaignId: r.campaign.id,
      senderEmail: r.senderAccountId ? senderMap[r.senderAccountId] || null : null,
    }));

    return NextResponse.json({ ok: true, type, count: items.length, items });
  } catch (err: any) {
    console.error('[live/details]', err);
    return jsonError(err?.message ?? 'Server error', 500);
  }
}
