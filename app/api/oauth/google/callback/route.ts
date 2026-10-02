import { NextResponse } from 'next/server';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { prisma } from '@/lib/prisma';
import { encrypt } from '@/lib/crypto';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";


export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  if (!code) return NextResponse.json({ error: 'Missing code' }, { status: 400 });
  const c = oauthClient();
  const { tokens } = await c.getToken(code);
  c.setCredentials(tokens);
  const oauth2 = google.oauth2({ version: 'v2', auth: c });
  const me = await oauth2.userinfo.get();
  const email = me.data.email!;

  await prisma.senderAccount.upsert({
    where: { email },
    create: {
      email,
      displayName: me.data.name ?? email,
      accessToken: tokens.access_token ? encrypt(tokens.access_token) : null,
      refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : null,
      tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : null,
      scope: tokens.scope,
      status: 'CONNECTED',
    },
    update: {
      accessToken: tokens.access_token ? encrypt(tokens.access_token) : undefined,
      refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : undefined,
      tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : undefined,
      status: 'CONNECTED',
    },
  });

  return NextResponse.redirect(new URL('/senders', process.env.APP_URL!));
}
