import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const list = await prisma.senderAccount.findMany({ orderBy: { createdAt: 'asc' } });
  return NextResponse.json(list.map(s => ({
    id: s.id, email: s.email, displayName: s.displayName, status: s.status,
    sentToday: s.sentToday, errors: s.errors, lastSuccessAt: s.lastSuccessAt,
    authorized: s.status === 'CONNECTED' && !!s.refreshToken,
  })));
}
