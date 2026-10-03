import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_: Request, { params }: { params: { id: string } }) {
  await prisma.campaign.update({ where:{id:params.id}, data:{status:"RUNNING"} }); return NextResponse.json({ ok:true });
}
