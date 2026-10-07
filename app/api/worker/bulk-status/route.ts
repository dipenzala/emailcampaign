import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { isBulkWorkerEnabled } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const enabled = await isBulkWorkerEnabled();

    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT', sentAt: { not: null } },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    const secondsSince = lastSent?.sentAt
      ? Math.floor((Date.now() - new Date(lastSent.sentAt).getTime()) / 1000)
      : null;

    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    const runningCampaigns = await prisma.campaign.count({
      where: { status: 'RUNNING' },
    });

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const sentToday = await prisma.campaignRecipient.count({
      where: { status: 'SENT', sentAt: { gte: todayStart } },
    });

    return NextResponse.json({
      ok: true,
      enabled,
      isLive: secondsSince !== null && secondsSince < 300,
      lastSentAt: lastSent?.sentAt || null,
      secondsSinceLastSend: secondsSince,
      queued,
      runningCampaigns,
      sentToday,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
