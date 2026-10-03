import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { connectRedis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      select: { id: true },
    });

    if (recips.length === 0) {
      return NextResponse.json({
        ok: true,
        queued: 0,
        message: 'No QUEUED recipients found',
      });
    }

    // Connect Redis first
    try {
      await connectRedis(8000);
    } catch (e: any) {
      return NextResponse.json({
        ok: false,
        error: 'Redis not reachable',
        message: e.message,
      }, { status: 500 });
    }

    const q = getSendQueue();

    // NO COLON — use dash separator
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: {
        jobId: params.id + '-' + r.id,
        attempts: 4,
        backoff: { type: 'exponential' as const, delay: 5000 },
        removeOnComplete: 1000,
        removeOnFail: 5000,
      },
    }));

    await q.addBulk(jobs);

    return NextResponse.json({
      ok: true,
      queued: jobs.length,
      total: recips.length,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[retry-queue]', err);
    return NextResponse.json({
      error: 'Retry failed',
      message: err?.message ?? String(err),
    }, { status: 500 });
  }
}
