import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: { recipients: { include: { contact: true }, take: 500 } },
    });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(campaign);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// FORCE DELETE — works even if RUNNING/PROCESSING
export async function DELETE(_: Request, { params }: { params: { id: string } }) {
  try {
    // 1. Stop the campaign first
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'STOPPED' },
    }).catch(() => {});

    // 2. Delete all recipients first (explicit, to handle FK)
    await prisma.campaignRecipient.deleteMany({
      where: { campaignId: params.id },
    });

    // 3. Delete the campaign
    await prisma.campaign.delete({ where: { id: params.id } });

    return NextResponse.json({ ok: true, message: 'Campaign force-deleted' });
  } catch (err: any) {
    // If campaign not found, still return success
    if (err.code === 'P2025') {
      return NextResponse.json({ ok: true, message: 'Campaign already deleted' });
    }
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
