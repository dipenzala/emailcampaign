import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Transparent 1x1 GIF
const PIXEL = Buffer.from(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  'base64'
);

export async function GET(req: Request, { params }: { params: { token: string } }) {
  const pixelResponse = () =>
    new NextResponse(PIXEL, {
      status: 200,
      headers: {
        'Content-Type': 'image/gif',
        'Content-Length': String(PIXEL.length),
        'Cache-Control': 'no-store, no-cache, must-revalidate, private',
        Pragma: 'no-cache',
        Expires: '0',
      },
    });

  try {
    // Decode token → recipientId
    let recipientId = '';
    try {
      recipientId = Buffer.from(params.token, 'base64url').toString();
    } catch {
      return pixelResponse();
    }

    if (!recipientId) return pixelResponse();

    // Get metadata
    const ua = req.headers.get('user-agent') || '';
    const forwarded = req.headers.get('x-forwarded-for') || '';
    const ip = forwarded.split(',')[0].trim() || req.headers.get('x-real-ip') || '';

    // Update recipient
    const recipient = await prisma.campaignRecipient.findUnique({
      where: { id: recipientId },
    });

    if (recipient) {
      const isFirstOpen = !recipient.openedAt;

      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: {
          openedAt: recipient.openedAt ?? new Date(),   // only first time
          openCount: { increment: 1 },
          userAgent: ua.slice(0, 500),
          ipAddress: ip.slice(0, 100),
        },
      });

      // Update campaign open count
      if (isFirstOpen) {
        await prisma.campaign.update({
          where: { id: recipient.campaignId },
          data: {
            openedCount: { increment: 1 },
          },
        }).catch(() => {});
      }
    }

    return pixelResponse();
  } catch (err) {
    // Always return pixel even on error
    return pixelResponse();
  }
}
