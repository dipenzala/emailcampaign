import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_: Request, { params }: { params: { id: string } }) {
  try {
    // Reset FAILED/PROCESSING recipients back to QUEUED
    const reset = await prisma.campaignRecipient.updateMany({
      where: {
        campaignId: params.id,
        status: { in: ['FAILED', 'PROCESSING'] },
      },
      data: {
        status: 'QUEUED',
        attemptCount: 0,
        errorMessage: null,
        errorCode: null,
        failedAt: null,
      },
    });

    // Ensure campaign is RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING' },
    });

    const queued = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });

    return NextResponse.json({
      ok: true,
      reset: reset.count,
      queued,
      message: 'Recipients queued. Worker will process from DB.',
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
