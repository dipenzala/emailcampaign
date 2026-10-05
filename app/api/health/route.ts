import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT' },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    return NextResponse.json({
      ok: true,
      ts: Date.now(),
      domain: process.env.APP_URL || 'http://localhost:3000',
      queue: {
        pending: queued,
        lastSentAt: lastSent?.sentAt || null,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
