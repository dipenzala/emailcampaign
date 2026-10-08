import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { checkEmail } from '@/lib/spam-checker';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();

  try {
    console.log('[start] Request for campaign:', params.id);

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'Campaign not found' }, { status: 404 });
    }

    // Spam check (non-blocking for now)
    let spamScore = 0;
    try {
      const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
      const report = checkEmail({
        subject: campaign.subject,
        html: campaign.html,
        fromEmail: sender?.email || 'noreply@example.com',
      });
      spamScore = report.score;
      await prisma.campaign.update({
        where: { id: params.id },
        data: { spamScore: report.score, spamIssues: report.issues as any },
      });
      // DO NOT block — let user start even with warning
    } catch (e) {
      console.warn('[start] spam check failed (ignored):', e);
    }

    // Count queued
    const queuedCount = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });

    if (queuedCount === 0) {
      return NextResponse.json({
        ok: false,
        error: 'No queued recipients in campaign',
      }, { status: 400 });
    }

    // Auto-enable workers
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch (e) {
      console.warn('[start] worker enable failed:', e);
    }

    // Mark RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    console.log('[start] ✅ Campaign RUNNING with', queuedCount, 'queued');

    return NextResponse.json({
      ok: true,
      queued: queuedCount,
      total: campaign.totalCount,
      spamScore,
      message: `Campaign started with ${queuedCount} recipients`,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start] FATAL:', err);
    return NextResponse.json({
      ok: false,
      error: 'Server error: ' + (err?.message || 'unknown'),
    }, { status: 500 });
  }
}
