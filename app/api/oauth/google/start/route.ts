import { NextResponse } from 'next/server';
import { oauthClient } from '@/lib/gmail';
export async function GET(req: Request) {
  const url = new URL(req.url);
  const senderEmail = url.searchParams.get('email') ?? '';
  const c = oauthClient();
  const auth = c.generateAuthUrl({
    access_type: 'offline',
    prompt: 'consent',
    scope: ['https://www.googleapis.com/auth/gmail.send','https://www.googleapis.com/auth/userinfo.email'],
    state: senderEmail,
  });
  return NextResponse.redirect(auth);
}
