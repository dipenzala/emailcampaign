import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

async function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timeout`)), ms)
    ),
  ]);
}

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({ subject: campaign.subject, html: campaign.html, fromEmail: sender?.email || 'noreply@example.com' });

    await prisma.campaign.update({ where: { id: params.id }, data: { spamScore: report.score, spamIssues: report.issues as any } });

    if (report.blocked) {
      return NextResponse.json({ error: 'Spam score too high', score: report.score, issues: report.issues }, { status: 400 });
    }

    await prisma.campaign.update({ where: { id: params.id }, data: { status: 'RUNNING', startedAt: new Date() } });

    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0, message: 'No pending recipients' });

    let queued = 0;
    let queueError: string | null = null;

    try {
      const q = getSendQueue();
      const jobs = recips.map((r) => ({
        name: 'send',
        data: { campaignId: params.id, recipientId: r.id },
        opts: {
          jobId: `${params.id}:${r.id}`,
          attempts: 4,
          backoff: { type: 'exponential' as const, delay: 5000 },
          removeOnComplete: 1000,
          removeOnFail: 5000,
        },
      }));
      await withTimeout(q.addBulk(jobs), 10000, 'addBulk');
      queued = jobs.length;
    } catch (qerr: any) {
      queueError = qerr?.message || String(qerr);
      console.error('[start] Queue error:', queueError);
    }

    return NextResponse.json({ ok: true, queued, total: recips.length, spamScore: report.score, queueError: queueError || undefined, elapsed: Date.now() - t0 });
  } catch (err: any) {
    console.error('[start] Fatal:', err);
    return NextResponse.json({ error: 'Failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
