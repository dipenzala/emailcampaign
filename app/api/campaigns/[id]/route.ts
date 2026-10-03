import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET single campaign
export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: {
        recipients: {
          include: { contact: true },
          take: 200,
        },
      },
    });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(campaign);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// DELETE campaign
export async function DELETE(_: Request, { params }: { params: { id: string } }) {
  try {
    await prisma.campaign.delete({ where: { id: params.id } });
    return NextResponse.json({ ok: true, message: 'Campaign deleted' });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
