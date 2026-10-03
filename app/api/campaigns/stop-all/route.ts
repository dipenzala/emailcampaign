import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST() {
  try {
    // 1. Mark all RUNNING/PAUSED campaigns as STOPPED
    const stopped = await prisma.campaign.updateMany({
      where: { status: { in: ['RUNNING', 'PAUSED', 'DRAFT'] } },
      data: { status: 'STOPPED', completedAt: new Date() },
    });

    // 2. Mark all QUEUED/PROCESSING recipients as SKIPPED (won't be sent)
    const skipped = await prisma.campaignRecipient.updateMany({
      where: { status: { in: ['QUEUED', 'PROCESSING'] } },
      data: { status: 'SKIPPED', errorMessage: 'Stopped by user' },
    });

    return NextResponse.json({
      ok: true,
      campaigns_stopped: stopped.count,
      recipients_skipped: skipped.count,
      message: `Stopped ${stopped.count} campaigns, ${skipped.count} recipients skipped`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
