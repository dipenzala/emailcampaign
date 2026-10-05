import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const PIXEL = Buffer.from(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  'base64'
);

export async function GET(req: Request, { params }: { params: { id: string } }) {
  try {
    const existing = await prisma.campaignRecipient.findUnique({
      where: { id: params.id },
      select: { openCount: true } as any,
    });

    if (existing) {
      const isFirstOpen = ((existing as any).openCount ?? 0) === 0;

      await prisma.campaignRecipient.update({
        where: { id: params.id },
        data: {
          openCount: { increment: 1 } as any,
          lastOpenedAt: new Date() as any,
          ...(isFirstOpen ? { firstOpenedAt: new Date() as any } : {}),
        } as any,
      });
    }
  } catch (err) {
    // Silent
  }

  return new Response(PIXEL, {
    status: 200,
    headers: {
      'Content-Type': 'image/gif',
      'Cache-Control': 'no-store, no-cache, must-revalidate, private, max-age=0',
      'Pragma': 'no-cache',
      'Expires': '0',
    },
  });
}
