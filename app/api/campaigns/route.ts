import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

const Schema = z.object({
  name: z.string().min(1),
  subject: z.string().min(1),
  html: z.string().min(20),
  emails: z.array(z.string().email()).min(1).max(10000),
  batchLimit: z.number().int().min(1).max(350).optional(),
});

export async function POST(req: Request) {
  try {
    const parsed = Schema.safeParse(await req.json());
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
    }
    const { name, subject, html, emails, batchLimit } = parsed.data;

    const uniqueEmails = [...new Set(emails.map(e => e.toLowerCase().trim()))];
    console.log('[campaign create] unique emails:', uniqueEmails.length);

    // ── Bulk upsert contacts using createMany (skipDuplicates)
    try {
      await prisma.contact.createMany({
        data: uniqueEmails.map(email => ({ email })),
        skipDuplicates: true,
      });
    } catch (e: any) {
      console.warn('[campaign create] createMany failed:', e.message);
    }

    // ── Fetch contacts (only the ones we need)
    const contacts = await prisma.contact.findMany({
      where: { email: { in: uniqueEmails } },
      select: { id: true, email: true },
    });

    console.log('[campaign create] contacts found:', contacts.length);

    // ── Suppression list
    const suppressionList = await prisma.suppressionList.findMany({
      where: { email: { in: uniqueEmails } },
      select: { email: true },
    });
    const suppressed = new Set(suppressionList.map(s => s.email));

    // ── Create campaign
    const campaign = await prisma.campaign.create({
      data: {
        name,
        subject,
        html,
        totalCount: contacts.length,
        status: 'DRAFT',
        batchLimit: batchLimit ?? 10,
      },
    });

    // ── Bulk create recipients
    const recipientData = contacts.map(c => ({
      campaignId: campaign.id,
      contactId: c.id,
      status: suppressed.has(c.email) ? 'SUPPRESSED' : 'QUEUED',
    }));

    // Insert in batches of 500
    const BATCH = 500;
    for (let i = 0; i < recipientData.length; i += BATCH) {
      const slice = recipientData.slice(i, i + BATCH);
      await prisma.campaignRecipient.createMany({
        data: slice,
        skipDuplicates: true,
      });
    }

    console.log('[campaign create] DONE, campaignId:', campaign.id);

    return NextResponse.json({
      ok: true,
      id: campaign.id,
      total: contacts.length,
      suppressed: suppressed.size,
    });
  } catch (err: any) {
    console.error('[campaign create] FATAL:', err);
    return NextResponse.json({
      error: err?.message || 'Campaign create failed',
    }, { status: 500 });
  }
}

export async function GET() {
  try {
    const list = await prisma.campaign.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return NextResponse.json(list);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
