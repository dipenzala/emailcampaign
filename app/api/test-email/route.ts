import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { gmailFor, oauthClient } from '@/lib/gmail';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";


export async function POST(req: Request) {
  const { to, subject, html } = await req.json();
  if (!to || !subject || !html) return NextResponse.json({ error:'Missing fields' }, { status:400 });

  const sender = await prisma.senderAccount.findFirst({ where: { status:'CONNECTED' } });
  if (!sender || !sender.refreshToken) return NextResponse.json({ error:'No connected sender' }, { status:400 });

  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = gmailFor(access, refresh);

  const body = renderTemplate(html, { name:'Test', email:to, company:'Acme', city:'', phone:'' });
  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to, subject, html: body, text: htmlToText(body),
  });

  const res = await gmail.users.messages.send({
    userId:'me',
    requestBody:{ raw: Buffer.from(raw).toString('base64url') },
  });
  return NextResponse.json({ ok:true, id: res.data.id });
}
