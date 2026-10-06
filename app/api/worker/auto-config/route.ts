import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Auto-detect optimal batch size and interval based on:
 * - Queue size
 * - Active senders count
 * - Daily limits available
 * - Time of day
 */
export async function GET() {
  try {
    // Queue size
    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    // Senders
    const senders = await prisma.senderAccount.findMany({
      where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    });

    const totalCapacity = senders.reduce((sum, s) => {
      const cap = s.dailyLimit || 350;
      return sum + Math.max(0, cap - s.sentToday);
    }, 0);

    // ═══════════════════════════════════════════
    // AUTO-CONFIG LOGIC
    // ═══════════════════════════════════════════

    let mode = 'balanced';
    let batchSize = 20;
    let intervalSec = 5;
    let reasoning = '';

    if (queued === 0) {
      mode = 'idle';
      batchSize = 5;
      intervalSec = 10;
      reasoning = 'No queued emails — idle mode';
    } else if (queued <= 10) {
      mode = 'small';
      batchSize = 5;
      intervalSec = 3;
      reasoning = `Small queue (${queued}) — quick mode`;
    } else if (queued <= 100) {
      mode = 'medium';
      batchSize = 10;
      intervalSec = 4;
      reasoning = `Medium queue (${queued}) — balanced`;
    } else if (queued <= 1000) {
      mode = 'large';
      batchSize = 25;
      intervalSec = 5;
      reasoning = `Large queue (${queued}) — throughput mode`;
    } else {
      mode = 'massive';
      batchSize = 50;
      intervalSec = 8;
      reasoning = `Massive queue (${queued}) — bulk mode`;
    }

    // Safety: don't exceed sender capacity
    if (totalCapacity > 0 && batchSize > totalCapacity) {
      batchSize = Math.max(1, Math.min(batchSize, totalCapacity));
      reasoning += ` (capped by sender capacity: ${totalCapacity})`;
    }

    // Safety: keep under Gmail rate limits
    // 20 req/sec per sender, but we want ~240 emails/min max
    const emailsPerMin = (batchSize / intervalSec) * 60;
    if (emailsPerMin > 300) {
      intervalSec = Math.ceil(batchSize / 5);
      reasoning += ` (interval adjusted for safety)`;
    }

    return NextResponse.json({
      ok: true,
      mode,
      batchSize,
      intervalSec,
      emailsPerMin: Math.round((batchSize / intervalSec) * 60),
      reasoning,
      queue: {
        queued,
        senders: senders.length,
        totalCapacity,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
