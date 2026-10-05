import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const list = await prisma.senderAccount.findMany({
      orderBy: { createdAt: 'asc' },
    });

    return NextResponse.json(
      list.map(s => ({
        id: s.id,
        email: s.email,
        // ⭐ Always return "Startup Team" if no name set
        displayName: s.displayName || 'Startup Team',
        status: s.status,
        sentToday: s.sentToday,
        dailyLimit: s.dailyLimit || 350,
        errors: s.errors,
        reputationScore: s.reputationScore ?? 100,
        lastSuccessAt: s.lastSuccessAt,
        authorized: s.status === 'CONNECTED' && !!s.refreshToken,
        isActive: s.isActive,
      }))
    );
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
