import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const appUrl = process.env.APP_URL || url.origin;

  if (error) return NextResponse.json({ error: 'Google error', detail: error }, { status: 400 });
  if (!code) return NextResponse.json({ error: 'Missing code' }, { status: 400 });

  const env = {
    GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID,
    GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET,
    GOOGLE_REDIRECT_URI: process.env.GOOGLE_REDIRECT_URI,
    TOKEN_ENCRYPTION_KEY: process.env.TOKEN_ENCRYPTION_KEY,
    DATABASE_URL: process.env.DATABASE_URL,
  };
  const missing = Object.entries(env).filter(([, v]) => !v).map(([k]) => k);
  if (missing.length) return NextResponse.json({ error: 'Missing env vars', missing }, { status: 500 });
  if (!/^[0-9a-fA-F]{64}$/.test(env.TOKEN_ENCRYPTION_KEY!)) {
    return NextResponse.json({ error: 'TOKEN_ENCRYPTION_KEY invalid' }, { status: 500 });
  }

  try {
    const { oauthClient } = await import('@/lib/gmail');
    const { prisma } = await import('@/lib/prisma');
    const { encrypt } = await import('@/lib/crypto');
    const { google } = await import('googleapis');

    const c = oauthClient();
    const { tokens } = await c.getToken(code);
    c.setCredentials(tokens);

    const oauth2 = google.oauth2({ version: 'v2', auth: c });
    const me = await oauth2.userinfo.get();
    const email = me.data.email;
    if (!email) throw new Error('Could not get email');

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
        isActive: true,
        warmupEnabled: false,
        dailyLimit: 500,
        warmupStartedAt: new Date(),
      },
      update: {
        accessToken: tokens.access_token ? encrypt(tokens.access_token) : undefined,
        refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : undefined,
        tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : undefined,
        scope: tokens.scope,
        status: 'CONNECTED',
        isActive: true,
      },
    });

    return NextResponse.redirect(`${appUrl}/senders?connected=${encodeURIComponent(email)}`);
  } catch (err: any) {
    console.error('[oauth/callback]', err);
    return NextResponse.json({ error: 'OAuth failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
