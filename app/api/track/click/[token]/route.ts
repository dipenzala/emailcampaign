import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: { token: string } }) {
  try {
    const url = new URL(req.url);
    const targetUrl = url.searchParams.get('url') || '';

    // Decode token → recipientId
    let recipientId = '';
    try {
      recipientId = Buffer.from(params.token, 'base64url').toString();
    } catch {
      return NextResponse.redirect(targetUrl || '/');
    }

    if (recipientId) {
      try {
        const r = await prisma.campaignRecipient.findUnique({ where: { id: recipientId } });
        if (r) {
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
            data: {
              clickedAt: r.clickedAt ?? new Date(),
              clickCount: { increment: 1 },
            },
          });
          if (!r.clickedAt) {
            await prisma.campaign.update({
              where: { id: r.campaignId },
              data: { clickedCount: { increment: 1 } },
            }).catch(() => {});
          }
        }
      } catch {}
    }

    // Redirect to actual URL
    if (targetUrl) {
      return NextResponse.redirect(targetUrl);
    }
    return NextResponse.redirect('/');
  } catch {
    return NextResponse.redirect('/');
  }
}
