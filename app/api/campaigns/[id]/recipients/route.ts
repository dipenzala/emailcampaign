import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const url = new URL(req.url);
  const status = url.searchParams.get('status');
  const where: any = { campaignId: params.id };
  if (status && status !== 'ALL') where.status = status;
  const list = await prisma.campaignRecipient.findMany({ where, take: 500, orderBy: { queuedAt: 'asc' }, include: { contact: true } });
  return NextResponse.json(list.map(r => ({ id: r.id, email: r.contact.email, name: r.contact.name, status: r.status, error: r.errorMessage, sentAt: r.sentAt })));
}
