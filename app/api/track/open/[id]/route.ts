import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// 1x1 transparent GIF
const PIXEL = Buffer.from(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  'base64'
);

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();

  try {
    const existing = await prisma.campaignRecipient.findUnique({
      where: { id: params.id },
      select: {
        id: true,
        openCount: true,
        campaignId: true,
        contactId: true,
      } as any,
    });

    if (existing) {
      const isFirst = ((existing as any).openCount ?? 0) === 0;

      await prisma.campaignRecipient.update({
        where: { id: params.id },
        data: {
          openCount: { increment: 1 } as any,
          lastOpenedAt: new Date() as any,
          ...(isFirst ? { firstOpenedAt: new Date() as any } : {}),
        } as any,
      });

      // Also update campaign's opened count
      if (isFirst) {
        try {
          await prisma.campaign.update({
            where: { id: existing.campaignId },
            data: { deliveredCount: { increment: 1 } },
          });
        } catch {}
      }

      console.log('[track] OPEN', params.id, '| count:', ((existing as any).openCount ?? 0) + 1);
    }
  } catch (err: any) {
    console.error('[track] error:', err?.message);
  }

  return new Response(PIXEL, {
    status: 200,
    headers: {
      'Content-Type': 'image/gif',
      'Content-Length': String(PIXEL.length),
      'Cache-Control': 'no-store, no-cache, must-revalidate, private, max-age=0',
      Pragma: 'no-cache',
      Expires: '0',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
