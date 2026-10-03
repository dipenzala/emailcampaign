import { NextResponse } from 'next/server';
import { oauthClient } from '@/lib/gmail';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const senderEmail = url.searchParams.get('email') || '';

    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    const redirectUri = process.env.GOOGLE_REDIRECT_URI;

    if (!clientId || !clientSecret || !redirectUri) {
      return NextResponse.json({
        error: 'OAuth not configured',
        missing: {
          GOOGLE_CLIENT_ID: !clientId,
          GOOGLE_CLIENT_SECRET: !clientSecret,
          GOOGLE_REDIRECT_URI: !redirectUri,
        },
      }, { status: 500 });
    }

    const c = oauthClient();
    const auth = c.generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: [
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/userinfo.email',
      ],
      state: senderEmail,
    });
    return NextResponse.redirect(auth);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
