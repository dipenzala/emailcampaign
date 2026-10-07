import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: { token: string } }) {
  const url = new URL(req.url);
  const action = url.searchParams.get('action') || 'approve';
  const token = params.token;

  try {
    const campaign = await prisma.campaign.findUnique({
      where: { approvalToken: token },
    });

    if (!campaign) {
      return NextResponse.json({ error: 'Invalid or expired token' }, { status: 404 });
    }

    if (campaign.approvalStatus === 'APPROVED') {
      return NextResponse.json({
        ok: true,
        message: 'Already approved',
        status: 'APPROVED',
        campaignId: campaign.id,
      });
    }

    if (action === 'reject' || action === 'cancel') {
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: {
          approvalStatus: 'REJECTED',
          rejectedAt: new Date(),
          status: 'STOPPED',
        },
      });

      return NextResponse.json({
        ok: true,
        message: 'Campaign rejected. No emails will be sent.',
        status: 'REJECTED',
        campaignId: campaign.id,
      });
    }

    // APPROVE
    await prisma.campaign.update({
      where: { id: campaign.id },
      data: {
        approvalStatus: 'APPROVED',
        approvedAt: new Date(),
        status: 'RUNNING',
        startedAt: new Date(),
      },
    });

    // Auto-enable both workers
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch {}

    return NextResponse.json({
      ok: true,
      message: 'Approved! Emails starting now.',
      status: 'APPROVED',
      campaignId: campaign.id,
      totalRecipients: campaign.totalCount,
    });
  } catch (err: any) {
    console.error('[approve]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
