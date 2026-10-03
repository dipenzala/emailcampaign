import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { confirm } = await req.json();
    if (confirm !== 'DELETE ALL') {
      return NextResponse.json({ error: 'Confirmation required' }, { status: 400 });
    }

    // Count first
    const count = await prisma.campaign.count();

    // Delete all campaigns (cascades to recipients)
    await prisma.campaign.deleteMany({});

    return NextResponse.json({
      ok: true,
      deleted: count,
      message: `Deleted ${count} campaigns`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
