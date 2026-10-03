import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { connectRedis } from '@/lib/redis';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });

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

    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      select: { id: true },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, queued: 0 });
    }

    // Ensure Redis is connected BEFORE queueing
    try {
      await connectRedis(8000);
    } catch (e: any) {
      console.error('[start] Redis connect failed:', e.message);
      return NextResponse.json(
        {
          ok: true,
          queued: 0,
          total: recips.length,
          warning: 'Redis not reachable — campaign marked RUNNING. Retry via /retry-queue once Redis is back.',
          redis_error: e.message,
          elapsed: Date.now() - t0,
        },
        { status: 200 }
      );
    }

    const q = getSendQueue();
    const jobs = recips.map(r => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: { jobId: `${params.id}-${r.id}` },
    }));

    await q.addBulk(jobs);

    return NextResponse.json({
      ok: true,
      queued: jobs.length,
      total: recips.length,
      spamScore: report.score,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start]', err);
    return NextResponse.json(
      { error: 'Failed', message: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
