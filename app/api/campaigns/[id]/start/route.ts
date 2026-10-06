import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { checkEmail } from '@/lib/spam-checker';
import { enableWorker, isWorkerEnabled } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();

  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // ── Spam check
    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({
      subject: campaign.subject,
      html: campaign.html,
      fromEmail: sender?.email || 'noreply@example.com',
    });

    await prisma.campaign.update({
      where: { id: params.id },
      data: { spamScore: report.score, spamIssues: report.issues as any },
    });

    if (report.blocked) {
      return NextResponse.json(
        { error: 'Spam score too high', score: report.score, issues: report.issues },
        { status: 400 }
      );
    }

    // ── Check queue has recipients
    const queuedCount = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });
    if (queuedCount === 0) {
      return NextResponse.json({ error: 'No queued recipients' }, { status: 400 });
    }

    // ═══════════════════════════════════════════
    // ⚡ AUTO-ENABLE WORKER ON LAUNCH
    // ═══════════════════════════════════════════
    const wasEnabled = await isWorkerEnabled();
    if (!wasEnabled) {
      await enableWorker();
      console.log('[start] Worker was OFF — auto-enabled');
    }

    // ── Mark campaign RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    console.log('[start] Campaign', params.id, 'RUNNING |', queuedCount, 'queued | worker:', wasEnabled ? 'was ON' : 'auto-enabled');

    return NextResponse.json({
      ok: true,
      queued: queuedCount,
      total: campaign.totalCount,
      spamScore: report.score,
      workerAutoEnabled: !wasEnabled,
      message: wasEnabled
        ? 'Campaign started. Worker already running.'
        : 'Campaign started. Worker auto-enabled.',
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start] FATAL:', err);
    return NextResponse.json(
      { error: 'Failed to start', message: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
