import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
  if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
  const report = checkEmail({ subject: campaign.subject, html: campaign.html, fromEmail: sender?.email || 'noreply@example.com' });
  await prisma.campaign.update({ where: { id: params.id }, data: { spamScore: report.score, spamIssues: report.issues as any } });
  if (report.blocked) return NextResponse.json({ error: 'Spam score too high', score: report.score, issues: report.issues }, { status: 400 });
  await prisma.campaign.update({ where: { id: params.id }, data: { status: 'RUNNING', startedAt: new Date() } });
  const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' } });
  const q = getSendQueue();
  await q.addBulk(recips.map(r => ({
    name: 'send',
    data: { campaignId: params.id, recipientId: r.id },
    opts: { jobId: `${params.id}:${r.id}`, attempts: 4, backoff: { type: 'exponential', delay: 5000 }, removeOnComplete: 1000, removeOnFail: 5000 },
  })));
  return NextResponse.json({ ok: true, queued: recips.length, spamScore: report.score });
}
