import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export async function GET(_:Request,{params}:{params:{id:string}}) {
  const c = await prisma.campaign.findUnique({ where:{id:params.id}});
  if (!c) return NextResponse.json({error:'Not found'},{status:404});
  const counts = await prisma.campaignRecipient.groupBy({
    by:['status'], where:{campaignId:params.id}, _count:{_all:true},
  });
  const byStatus: Record<string,number> = {};
  counts.forEach(g => byStatus[g.status] = g._count._all);
  const pending = (byStatus.QUEUED ?? 0) + (byStatus.PROCESSING ?? 0);
  const progress = c.totalCount ? ((c.totalCount - pending) / c.totalCount) * 100 : 0;
  return NextResponse.json({
    campaign: c,
    counts: {
      total: c.totalCount,
      queued: byStatus.QUEUED ?? 0,
      processing: byStatus.PROCESSING ?? 0,
      sent: byStatus.SENT ?? 0,
      delivered: byStatus.DELIVERED ?? 0,
      failed: byStatus.FAILED ?? 0,
      bounced: byStatus.BOUNCED ?? 0,
      suppressed: byStatus.SUPPRESSED ?? 0,
      pending,
      progress: Number(progress.toFixed(2)),
    },
    updatedAt: Date.now(),
  });
}
