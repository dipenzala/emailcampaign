import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const campaignId = url.searchParams.get('campaignId');
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '200'), 500);

    const where: any = {
      openCount: { gt: 0 } as any,
    };

    if (campaignId) where.campaignId = campaignId;

    const opened = await prisma.campaignRecipient.findMany({
      where,
      orderBy: { lastOpenedAt: 'desc' } as any,
      take: limit,
      include: {
        contact: { select: { email: true, name: true, company: true } },
        campaign: { select: { id: true, name: true, subject: true } },
      },
    });

    // Get sender emails
    const senderIds = [...new Set(opened.map(o => o.senderAccountId).filter(Boolean))] as string[];
    const senders = senderIds.length
      ? await prisma.senderAccount.findMany({
          where: { id: { in: senderIds } },
          select: { id: true, email: true, displayName: true },
        })
      : [];
    const senderMap: Record<string, any> = {};
    senders.forEach(s => { senderMap[s.id] = s; });

    const items = opened.map(o => ({
      id: o.id,
      email: o.contact.email,
      name: o.contact.name,
      company: o.contact.company,
      status: o.status,
      openCount: (o as any).openCount ?? 0,
      firstOpenedAt: (o as any).firstOpenedAt,
      lastOpenedAt: (o as any).lastOpenedAt,
      sentAt: o.sentAt,
      campaignName: o.campaign.name,
      campaignSubject: o.campaign.subject,
      campaignId: o.campaign.id,
      senderEmail: o.senderAccountId ? senderMap[o.senderAccountId]?.email : null,
      senderName: o.senderAccountId ? senderMap[o.senderAccountId]?.displayName : null,
    }));

    // Stats
    const total = await prisma.campaignRecipient.count({ where });
    const totalSent = await prisma.campaignRecipient.count({
      where: { status: { in: ['SENT', 'DELIVERED'] } },
    });

    return NextResponse.json({
      ok: true,
      items,
      stats: {
        totalOpened: total,
        totalSent,
        openRate: totalSent > 0 ? ((total / totalSent) * 100).toFixed(1) : '0',
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
