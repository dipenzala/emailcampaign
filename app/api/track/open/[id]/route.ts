import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// 1x1 transparent GIF
const PIXEL = Buffer.from(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  'base64'
);

export async function GET(req: Request, { params }: { params: { id: string } }) {
  try {
    // Log the open
    await prisma.campaignRecipient.update({
      where: { id: params.id },
      data: {
        firstOpenedAt: new Date(),
        lastOpenedAt: new Date(),
        openCount: { increment: 1 },
        status: 'OPENED',
      },
    }).catch(() => {
      // If OPENED column doesn't exist yet, try simpler update
      return prisma.campaignRecipient.update({
        where: { id: params.id },
        data: {
          // fallback: just mark it as read via existing field
          deliveredAt: new Date(),
        },
      }).catch(() => {});
    });
  } catch (err) {
    // Silent fail — still return pixel
  }

  return new Response(PIXEL, {
    status: 200,
    headers: {
      'Content-Type': 'image/gif',
      'Content-Length': String(PIXEL.length),
      'Cache-Control': 'no-store, no-cache, must-revalidate, private',
      'Pragma': 'no-cache',
      'Expires': '0',
    },
  });
}
