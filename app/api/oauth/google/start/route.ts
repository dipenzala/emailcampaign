import { NextResponse } from 'next/server';
import { oauthClient } from '@/lib/gmail';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const senderEmail = url.searchParams.get('email') ?? '';
    const c = oauthClient();
    const auth = c.generateAuthUrl({ access_type: 'offline', prompt: 'consent', scope: ['https://www.googleapis.com/auth/gmail.send','https://www.googleapis.com/auth/userinfo.email'], state: senderEmail });
    return NextResponse.redirect(auth);
  } catch (err: any) {
    return NextResponse.json({ error: 'OAuth start failed', message: err?.message ?? String(err), hint: 'Check GOOGLE_CLIENT_ID/SECRET/REDIRECT_URI' }, { status: 500 });
  }
}
