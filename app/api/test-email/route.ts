import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { gmailFor } from '@/lib/gmail';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { to, subject, html } = await req.json();
  if (!to || !subject || !html) return NextResponse.json({ error: 'Missing fields' }, { status: 400 });
  const spam = checkEmail({ subject, html, fromEmail: to });
  if (spam.blocked) return NextResponse.json({ error: 'Spam score too high', score: spam.score, issues: spam.issues }, { status: 400 });
  const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
  if (!sender || !sender.refreshToken) return NextResponse.json({ error: 'No connected sender' }, { status: 400 });
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const gmail = gmailFor(access, refresh);
  const body = renderTemplate(html, { name: 'Test', email: to, company: 'Acme', city: '', phone: '' });
  const raw = buildMime({ from: `${sender.displayName ?? sender.email} <${sender.email}>`, to, subject, html: body, text: htmlToText(body) });
  const res = await gmail.users.messages.send({ userId: 'me', requestBody: { raw: Buffer.from(raw).toString('base64url') } });
  return NextResponse.json({ ok: true, id: res.data.id, spamScore: spam.score });
}
