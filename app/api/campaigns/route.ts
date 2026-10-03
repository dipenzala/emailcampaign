import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const Schema = z.object({
  name: z.string().min(1),
  subject: z.string().min(1),
  html: z.string().min(20),
  emails: z.array(z.string().email()).min(1),
  batchLimit: z.number().int().min(1).max(500).optional(),
});
export async function POST(req: Request) {
  const parsed = Schema.safeParse(await req.json());
  if (!parsed.success) return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  const { name, subject, html, emails, batchLimit } = parsed.data;
  const contacts = await prisma.contact.findMany({ where: { email: { in: emails } } });
  const suppressed = new Set((await prisma.suppressionList.findMany()).map(s => s.email));
  const campaign = await prisma.campaign.create({ data: { name, subject, html, totalCount: contacts.length, status: 'DRAFT', batchLimit: batchLimit ?? 10 } });
  for (const c of contacts) {
    await prisma.campaignRecipient.create({ data: { campaignId: campaign.id, contactId: c.id, status: suppressed.has(c.email) ? 'SUPPRESSED' : 'QUEUED' } });
  }
  return NextResponse.json({ id: campaign.id });
}
export async function GET() {
  const list = await prisma.campaign.findMany({ orderBy: { createdAt: 'desc' } });
  return NextResponse.json(list);
}
