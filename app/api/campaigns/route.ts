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
});

export async function POST(req: Request) {
  const body = await req.json();
  const parsed = Schema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  const { name, subject, html, emails } = parsed.data;

  const contacts = await prisma.contact.findMany({ where: { email: { in: emails } } });
  const suppressed = new Set((await prisma.suppressionList.findMany()).map(s => s.email));

  const campaign = await prisma.campaign.create({
    data: { name, subject, html, totalCount: contacts.length, status: 'DRAFT' },
  });

  for (const c of contacts) {
    const isSuppressed = suppressed.has(c.email);
    await prisma.campaignRecipient.create({
      data: {
        campaignId: campaign.id,
        contactId: c.id,
        status: isSuppressed ? 'SUPPRESSED' : 'QUEUED',
      },
    });
  }

  return NextResponse.json({ id: campaign.id });
}

export async function GET() {
  const list = await prisma.campaign.findMany({ orderBy: { createdAt: 'desc' } });
  return NextResponse.json(list);
}
