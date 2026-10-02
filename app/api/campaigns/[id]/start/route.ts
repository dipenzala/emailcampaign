import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { sendQueue } from '@/lib/queue';

export async function POST(_: Request, { params }: { params: { id: string }}) {
  const campaign = await prisma.campaign.findUnique({ where: { id: params.id }});
  if (!campaign) return NextResponse.json({ error:'Not found' }, { status:404 });

  await prisma.campaign.update({ where:{ id: params.id }, data:{ status:'RUNNING', startedAt:new Date() }});

  const recips = await prisma.campaignRecipient.findMany({
    where: { campaignId: params.id, status: 'QUEUED' },
  });
  await sendQueue.addBulk(recips.map(r => ({
    name: 'send',
    data: { campaignId: params.id, recipientId: r.id },
    opts: {
      jobId: `${params.id}:${r.id}`,          // idempotency
      attempts: 4,
      backoff: { type:'exponential', delay: 5000 },
      removeOnComplete: 1000,
      removeOnFail: 5000,
    },
  })));

  return NextResponse.json({ ok:true, queued: recips.length });
}
