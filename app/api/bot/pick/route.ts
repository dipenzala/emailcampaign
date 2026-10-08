import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

/**
 * ATOMIC PICK
 * -----------
 * Uses Postgres FOR UPDATE SKIP LOCKED to claim emails.
 * Multiple bots can call this in parallel without duplicates.
 * Each bot gets a UNIQUE set of recipients.
 */
export async function POST(req: Request) {
  try {
    const { botId, batchSize = 15 } = await req.json();

    if (!botId) {
      return NextResponse.json({ error: 'botId required' }, { status: 400 });
    }

    // ═══════════════════════════════════════════
    // ATOMIC CLAIM via raw SQL
    // ═══════════════════════════════════════════
    // 1. Find N queued emails
    // 2. Atomically lock them (SKIP LOCKED so other bots skip)
    // 3. Mark as PROCESSING with botId
    // 4. Return claimed rows

    const claimed: any[] = await prisma.$queryRawUnsafe(`
      WITH claimed AS (
        SELECT id
        FROM "CampaignRecipient"
        WHERE status = 'QUEUED'
          AND "campaignId" IN (
            SELECT id FROM "Campaign"
            WHERE status = 'RUNNING'
              AND ("approvalRequired" = false OR "approvalStatus" = 'APPROVED')
          )
        ORDER BY "queuedAt" ASC
        LIMIT $1
        FOR UPDATE SKIP LOCKED
      )
      UPDATE "CampaignRecipient" cr
      SET
        status = 'PROCESSING',
        "attemptCount" = cr."attemptCount" + 1,
        "errorMessage" = $2
      FROM claimed
      WHERE cr.id = claimed.id
      RETURNING cr.id, cr."campaignId", cr."contactId"
    `, batchSize, `CLAIMED_BY:${botId}:${Date.now()}`);

    if (claimed.length === 0) {
      return NextResponse.json({
        ok: true,
        botId,
        claimed: 0,
        recipients: [],
      });
    }

    // Fetch full recipient data
    const recipientIds = claimed.map((c: any) => c.id);
    const fullData = await prisma.campaignRecipient.findMany({
      where: { id: { in: recipientIds } },
      include: { contact: true, campaign: true },
    });

    return NextResponse.json({
      ok: true,
      botId,
      claimed: fullData.length,
      recipients: fullData.map(r => ({
        id: r.id,
        campaignId: r.campaignId,
        contactId: r.contactId,
        contact: {
          email: r.contact.email,
          name: r.contact.name,
          company: r.contact.company,
          city: r.contact.city,
          phone: r.contact.phone,
        },
        campaign: {
          id: r.campaign.id,
          name: r.campaign.name,
          subject: r.campaign.subject,
          html: r.campaign.html,
          batchLimit: r.campaign.batchLimit,
        },
      })),
    });
  } catch (err: any) {
    console.error('[bot/pick] error:', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
