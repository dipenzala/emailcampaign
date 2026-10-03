import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getRotationState, resetDailyCounters } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const { senders, currentSender } = await getRotationState();
    return NextResponse.json({ senders, currentSender });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const { id, dailyLimit, rotationOrder, isActive, warmupEnabled, batchCount } = await req.json();
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    const data: any = {};
    if (typeof dailyLimit === 'number') data.dailyLimit = dailyLimit;
    if (typeof rotationOrder === 'number') data.rotationOrder = rotationOrder;
    if (typeof isActive === 'boolean') data.isActive = isActive;
    if (typeof warmupEnabled === 'boolean') data.warmupEnabled = warmupEnabled;
    if (typeof batchCount === 'number') data.batchCount = batchCount;

    const updated = await prisma.senderAccount.update({ where: { id }, data });
    return NextResponse.json({ ok: true, sender: updated });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function PUT() {
  try {
    const count = await resetDailyCounters();
    return NextResponse.json({ ok: true, reset: count });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
