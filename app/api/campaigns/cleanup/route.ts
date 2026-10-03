import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { action } = await req.json();

    if (action === 'failed') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: { in: ['FAILED', 'BOUNCED'] } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Failed/bounced recipients removed' });
    }

    if (action === 'sent') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: 'SENT' },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Sent recipients removed' });
    }

    if (action === 'suppressed') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: 'SUPPRESSED' },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Suppressed recipients removed' });
    }

    if (action === 'empty-campaigns') {
      const empty = await prisma.campaign.findMany({
        where: { recipients: { none: {} } },
      });
      const r = await prisma.campaign.deleteMany({
        where: { id: { in: empty.map(c => c.id) } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Empty campaigns removed' });
    }

    if (action === 'old') {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const r = await prisma.campaign.deleteMany({
        where: { createdAt: { lt: thirtyDaysAgo } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Campaigns older than 30 days removed' });
    }

    return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
