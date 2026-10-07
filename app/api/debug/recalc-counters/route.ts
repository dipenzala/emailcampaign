import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Recalculate campaign counters from ACTUAL recipient data.
 * Fixes SENT > TOTAL bug by computing from source of truth.
 */
export async function POST(req: Request) {
  try {
    const { campaignId } = await req.json();
    if (!campaignId) {
      return NextResponse.json({ error: 'campaignId required' }, { status: 400 });
    }

    const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Count actual
    const [sent, failed, bounced, suppressed, queued, processing] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'FAILED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'BOUNCED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'SUPPRESSED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'QUEUED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'PROCESSING' } }),
    ]);

    const total = await prisma.campaignRecipient.count({ where: { campaignId } });

    // Update with actual counts
    await prisma.campaign.update({
      where: { id: campaignId },
      data: {
        totalCount: total,
        sentCount: sent,
        failedCount: failed,
        bouncedCount: bounced,
        suppressedCount: suppressed,
      },
    });

    return NextResponse.json({
      ok: true,
      previous: {
        totalCount: campaign.totalCount,
        sentCount: campaign.sentCount,
        failedCount: campaign.failedCount,
      },
      recalculated: {
        totalCount: total,
        sentCount: sent,
        failedCount: failed,
        bouncedCount: bounced,
        suppressedCount: suppressed,
        queued,
        processing,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
