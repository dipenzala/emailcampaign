import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { resetDailyCounters } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const senders = await prisma.senderAccount.findMany({
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: { id:true, email:true, displayName:true, status:true, isActive:true, sentToday:true, dailyLimit:true, batchCount:true, rotationOrder:true, errors:true, lastSuccessAt:true, warmupEnabled:true, warmupDay:true, reputationScore:true, hardBounces:true, softBounces:true, complaints:true },
  });
  return NextResponse.json({ senders });
}
export async function POST(req: Request) {
  const { id, dailyLimit, rotationOrder, isActive, warmupEnabled } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });
  const data: any = {};
  if (typeof dailyLimit === 'number') data.dailyLimit = dailyLimit;
  if (typeof rotationOrder === 'number') data.rotationOrder = rotationOrder;
  if (typeof isActive === 'boolean') data.isActive = isActive;
  if (typeof warmupEnabled === 'boolean') data.warmupEnabled = warmupEnabled;
  const updated = await prisma.senderAccount.update({ where: { id }, data });
  return NextResponse.json({ ok: true, sender: updated });
}
export async function PUT() {
  const count = await resetDailyCounters();
  return NextResponse.json({ ok: true, reset: count });
}
