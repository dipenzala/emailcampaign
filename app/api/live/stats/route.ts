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

    // Get all status counts
    const groups = await prisma.campaignRecipient.groupBy({
      by: ['status'],
      _count: { _all: true },
    });

    const byStatus: Record<string, number> = {};
    groups.forEach(g => { byStatus[g.status] = g._count._all; });

    // Opened count
    let opened = 0;
    try {
      opened = await prisma.campaignRecipient.count({
        where: { openCount: { gt: 0 } } as any,
      });
    } catch { opened = 0; }

    const queued = byStatus.QUEUED ?? 0;
    const processing = byStatus.PROCESSING ?? 0;
    const sent = byStatus.SENT ?? 0;
    const delivered = byStatus.DELIVERED ?? 0;
    const failed = byStatus.FAILED ?? 0;
    const bounced = byStatus.BOUNCED ?? 0;
    const suppressed = byStatus.SUPPRESSED ?? 0;
    const pending = queued + processing;

    // TOTAL = all recipients ever
    const totalRecipients = await prisma.campaignRecipient.count();

    // Campaign count
    const totalCampaigns = await prisma.campaign.count();

    const senders = await prisma.senderAccount.findMany({
      orderBy: [{ status: 'asc' }, { sentToday: 'asc' }],
      select: {
        email: true, sentToday: true, dailyLimit: true, batchCount: true,
        status: true, isActive: true, reputationScore: true,
      },
    });

    const campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });

    const recent = await prisma.campaignRecipient.findMany({
      take: 15,
      orderBy: { sentAt: 'desc' },
      where: { sentAt: { not: null } },
      include: { contact: true },
    });

    const activity = recent.map(r => {
      const isOpened = ((r as any).openCount ?? 0) > 0;
      return `[${r.sentAt ? new Date(r.sentAt).toLocaleTimeString() : '--'}] ${isOpened ? '👁️' : '✅'} ${r.contact.email}`;
    });

    return NextResponse.json({
      ok: true,
      stats: {
        total: totalRecipients,
        totalCampaigns,
        sent,
        delivered,
        failed,
        bounced,
        suppressed,
        pending,
        queued,
        processing,
        opened,
      },
      senders,
      campaign,
      activity,
      ts: Date.now(),
    });
  } catch (err: any) {
    console.error('[live/stats]', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
