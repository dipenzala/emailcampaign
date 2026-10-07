import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * Chunked upload endpoint.
 * Frontend parses Excel → splits into chunks of 5000 rows → sends each chunk here.
 * Server inserts bulk with createMany + skipDuplicates.
 */
export async function POST(req: Request) {
  try {
    const { campaignId, rows, finalize } = await req.json();

    if (!campaignId) {
      return NextResponse.json({ error: 'campaignId required' }, { status: 400 });
    }

    // Verify campaign
    const campaign = await prisma.campaign.findUnique({
      where: { id: campaignId },
    });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }
    if (campaign.campaignType !== 'scheduled') {
      return NextResponse.json({ error: 'Not a scheduled campaign' }, { status: 400 });
    }

    let inserted = 0;
    let duplicates = 0;
    let invalid = 0;
    let suppressed = 0;

    if (rows && Array.isArray(rows) && rows.length > 0) {
      // Fetch suppression list once
      const emails = rows
        .map((r: any) => String(r.email || '').trim().toLowerCase())
        .filter(Boolean);

      const suppressionSet = new Set<string>();
      if (emails.length > 0) {
        const sup = await prisma.suppressionList.findMany({
          where: { email: { in: emails } },
          select: { email: true },
        });
        sup.forEach(s => suppressionSet.add(s.email));
      }

      // Filter rows
      const validRows: any[] = [];
      const seenInChunk = new Set<string>();

      for (const row of rows) {
        const email = String(row.email || '').trim().toLowerCase();
        if (!email) { invalid++; continue; }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { invalid++; continue; }
        if (seenInChunk.has(email)) { duplicates++; continue; }
        seenInChunk.add(email);
        if (suppressionSet.has(email)) { suppressed++; continue; }

        validRows.push({
          email,
          company: String(row.company || '').trim().slice(0, 200),
        });
      }

      // Bulk upsert contacts
      try {
        await prisma.contact.createMany({
          data: validRows.map(r => ({
            email: r.email,
            company: r.company || null,
          })),
          skipDuplicates: true,
        });
      } catch (e: any) {
        console.warn('[chunk] contact createMany warning:', e.message);
      }

      // Fetch contacts to get IDs
      const contacts = await prisma.contact.findMany({
        where: { email: { in: validRows.map(r => r.email) } },
        select: { id: true, email: true },
      });
      const contactMap = new Map(contacts.map(c => [c.email, c.id]));

      // Insert campaign recipients
      const recipients = validRows
        .map(r => ({
          campaignId,
          contactId: contactMap.get(r.email) || '',
          status: 'QUEUED',
        }))
        .filter(r => r.contactId);

      // Insert in batches of 1000
      const BATCH = 1000;
      for (let i = 0; i < recipients.length; i += BATCH) {
        const slice = recipients.slice(i, i + BATCH);
        try {
          const res = await prisma.campaignRecipient.createMany({
            data: slice,
            skipDuplicates: true,
          });
          inserted += res.count;
        } catch (e: any) {
          console.warn('[chunk] recipient insert warning:', e.message);
        }
      }
    }

    // Finalize — update campaign total count
    if (finalize) {
      const totalCount = await prisma.campaignRecipient.count({
        where: { campaignId },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { totalCount },
      });
      return NextResponse.json({
        ok: true,
        finalized: true,
        inserted,
        duplicates,
        invalid,
        suppressed,
        totalCount,
      });
    }

    return NextResponse.json({
      ok: true,
      inserted,
      duplicates,
      invalid,
      suppressed,
    });
  } catch (err: any) {
    console.error('[chunk] error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
