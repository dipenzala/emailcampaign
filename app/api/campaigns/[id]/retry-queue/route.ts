import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_: Request, { params }: { params: { id: string } }) {
  try {
    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0, message: 'Nothing to queue' });
    const q = getSendQueue();
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: { jobId: `${params.id}:${r.id}`, attempts: 4, backoff: { type: 'exponential' as const, delay: 5000 }, removeOnComplete: 1000, removeOnFail: 5000 },
    }));
    await q.addBulk(jobs);
    return NextResponse.json({ ok: true, queued: jobs.length });
  } catch (err: any) {
    return NextResponse.json({ error: 'Queue retry failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
