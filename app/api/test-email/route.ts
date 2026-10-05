import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { gmailFor } from '@/lib/gmail';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { to, subject, html, senderId } = await req.json();
    if (!to || !subject || !html) {
      return NextResponse.json({ error: 'Missing: to, subject, html' }, { status: 400 });
    }

    const where: any = { status: 'CONNECTED', refreshToken: { not: null } };
    if (senderId) where.id = senderId;

    const sender = await prisma.senderAccount.findFirst({ where });
    if (!sender || !sender.refreshToken) {
      return NextResponse.json({ error: 'No connected sender available' }, { status: 400 });
    }

    const access = sender.accessToken ? decrypt(sender.accessToken) : '';
    const refresh = decrypt(sender.refreshToken);
    const gmail = gmailFor(access, refresh);

    const body = renderTemplate(html, {
      name: 'Test User',
      email: to,
      company: 'Test Company',
      city: 'Mumbai',
      phone: '+91 99999 99999',
    });

    const raw = buildMime({
      from: `${sender.displayName ?? sender.email} <${sender.email}>`,
      to,
      subject: '[TEST] ' + subject,
      html: body,
      text: htmlToText(body),
    });

    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });

    return NextResponse.json({
      ok: true,
      id: res.data.id,
      sender: sender.email,
      to,
    });
  } catch (err: any) {
    console.error('[test-email]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
