import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    let enabled = true;
    try {
      const rows: any[] = await prisma.$queryRawUnsafe(
        `SELECT value FROM worker_settings WHERE key = 'worker_enabled' LIMIT 1`
      );
      enabled = rows?.[0]?.value !== 'false';
    } catch {}

    // Get last sent time
    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT', sentAt: { not: null } },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    const lastSentAt = lastSent?.sentAt;
    const secondsSinceLastSend = lastSentAt
      ? Math.floor((Date.now() - new Date(lastSentAt).getTime()) / 1000)
      : null;

    // Worker is "live" if it sent something in last 5 minutes
    const isLive = secondsSinceLastSend !== null && secondsSinceLastSend < 300;

    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    return NextResponse.json({
      ok: true,
      enabled,
      isLive,
      lastSentAt,
      secondsSinceLastSend,
      queued,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
