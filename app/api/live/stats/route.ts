import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
    }

    const groups = await prisma.campaignRecipient.groupBy({
      by: ['status'],
      _count: { _all: true },
    });

    const byStatus: Record<string, number> = {};
    groups.forEach(g => { byStatus[g.status] = g._count._all; });

    const queued = byStatus.QUEUED ?? 0;
    const processing = byStatus.PROCESSING ?? 0;
    const sent = byStatus.SENT ?? 0;
    const delivered = byStatus.DELIVERED ?? 0;
    const failed = byStatus.FAILED ?? 0;
    const bounced = byStatus.BOUNCED ?? 0;
    const suppressed = byStatus.SUPPRESSED ?? 0;
    const pending = queued + processing;
    const total = queued + processing + sent + delivered + failed + bounced + suppressed;

    const senders = await prisma.senderAccount.findMany({
      orderBy: [{ status: 'asc' }, { sentToday: 'asc' }],
      select: {
        email: true, sentToday: true, dailyLimit: true, batchCount: true,
        status: true, isActive: true, reputationScore: true,
      },
    });

    const campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });

    // Recent activity
    const recent = await prisma.campaignRecipient.findMany({
      take: 15,
      orderBy: { sentAt: 'desc' },
      where: { sentAt: { not: null } },
      include: { contact: true },
    });

    const activity = recent.map(r =>
      `[${r.sentAt ? new Date(r.sentAt).toLocaleTimeString() : '--'}] ✅ ${r.contact.email}`
    );

    return NextResponse.json({
      ok: true,
      stats: { total, sent, delivered, failed, bounced, suppressed, pending, queued, processing },
      senders,
      campaign,
      activity,
      ts: Date.now(),
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
