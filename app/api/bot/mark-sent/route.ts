import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { recipientId, senderId, providerMessageId, status, error } = await req.json();

    if (!recipientId) return NextResponse.json({ error: 'recipientId required' }, { status: 400 });

    const update: any = {
      status: status || 'SENT',
      senderAccountId: senderId || null,
      providerMessageId: providerMessageId || null,
    };

    if (status === 'SENT') {
      update.sentAt = new Date();
      update.errorCode = null;
      update.errorMessage = null;
    } else if (status === 'FAILED' || status === 'BOUNCED') {
      update.errorMessage = error || null;
      update.failedAt = new Date();
    } else if (status === 'SUPPRESSED') {
      update.errorCode = 'SUPPRESSED';
      update.errorMessage = error || null;
    }

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: update,
    });

    // Update sender counters if sent
    if (status === 'SENT' && senderId) {
      await prisma.senderAccount.update({
        where: { id: senderId },
        data: {
          sentToday: { increment: 1 },
          batchCount: { increment: 1 },
          lastSuccessAt: new Date(),
        },
      }).catch(() => {});
    }

    // Refresh campaign counters
    const recipient = await prisma.campaignRecipient.findUnique({
      where: { id: recipientId },
      select: { campaignId: true },
    });

    if (recipient) {
      const [sent, total] = await Promise.all([
        prisma.campaignRecipient.count({ where: { campaignId: recipient.campaignId, status: 'SENT' } }),
        prisma.campaignRecipient.count({ where: { campaignId: recipient.campaignId } }),
      ]);
      await prisma.campaign.update({
        where: { id: recipient.campaignId },
        data: { sentCount: sent, totalCount: total },
      }).catch(() => {});

      // Auto complete
      const remaining = await prisma.campaignRecipient.count({
        where: { campaignId: recipient.campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
      });
      if (remaining === 0) {
        await prisma.campaign.update({
          where: { id: recipient.campaignId },
          data: { status: 'COMPLETED', completedAt: new Date() },
        }).catch(() => {});
      }
    }

    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
