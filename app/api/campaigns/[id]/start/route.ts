import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { triggerBotWorkflow } from '@/lib/github-trigger';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  const body = await req.json().catch(() => ({}));
  const batchSize = Math.min(40, Math.max(10, parseInt(body.batchSize || '20', 10)));

  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Count queued
    const queued = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });

    if (queued === 0) {
      return NextResponse.json({ error: 'No queued recipients' }, { status: 400 });
    }

    // Ensure campaigns running
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    // Enable worker flags
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch {}

    // ═══════════════════════════════════════════
    // 🚀 TRIGGER GITHUB ACTIONS — 3 BOTS PARALLEL
    // ═══════════════════════════════════════════
    const trigger = await triggerBotWorkflow({ batchSize, mode: 'run' });

    return NextResponse.json({
      ok: true,
      queued,
      total: campaign.totalCount,
      botTrigger: {
        triggered: trigger.ok,
        status: trigger.status || null,
        error: trigger.error || null,
      },
      message: trigger.ok
        ? `✅ Campaign started. 3 bots triggered instantly.`
        : `⚠️ Campaign started. Bot trigger failed: ${trigger.error}. Will auto-run every 5 min.`,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
