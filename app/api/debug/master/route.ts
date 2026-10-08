import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const [queued, runningCampaigns, senders, withToken, contacts, suppressed] = await Promise.all([
      prisma.campaignRecipient.count({ where: { status: 'QUEUED' } }),
      prisma.campaign.count({ where: { status: 'RUNNING' } }),
      prisma.senderAccount.count(),
      prisma.senderAccount.count({ where: { status: 'CONNECTED', refreshToken: { not: null } } }),
      prisma.contact.count(),
      prisma.suppressionList.count(),
    ]);

    const recentCampaign = await prisma.campaign.findFirst({
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { recipients: true } } },
    });

    let workerFlag = 'unknown';
    try {
      const rows: any[] = await prisma.$queryRawUnsafe(
        `SELECT value FROM worker_settings WHERE key = 'worker_enabled' LIMIT 1`
      );
      workerFlag = rows?.[0]?.value ?? 'not-set';
    } catch {}

    return NextResponse.json({
      ok: true,
      timestamp: new Date().toISOString(),
      counts: {
        queued,
        runningCampaigns,
        senders,
        sendersWithToken: withToken,
        contacts,
        suppressed,
      },
      workerFlag,
      latestCampaign: recentCampaign ? {
        id: recentCampaign.id,
        name: recentCampaign.name,
        status: recentCampaign.status,
        totalCount: recentCampaign.totalCount,
        sentCount: recentCampaign.sentCount,
        recipientsInDB: recentCampaign._count.recipients,
        approvalStatus: (recentCampaign as any).approvalStatus,
      } : null,
      diagnosis: {
        canSend: queued > 0 && withToken > 0 && runningCampaigns > 0,
        issue: queued === 0 ? 'No queued emails'
          : withToken === 0 ? 'No connected senders'
          : runningCampaigns === 0 ? 'No running campaigns'
          : 'Ready to send ✅',
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
