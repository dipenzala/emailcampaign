import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

async function verifySessionEdge(token: string, secret: string): Promise<boolean> {
  try {
    if (!token || !secret) return false;
    const parts = token.split('.');
    if (parts.length !== 2) return false;
    const [data, sig] = parts;

    const pad = (s: string) => s + '='.repeat((4 - (s.length % 4)) % 4);
    const b64urlToBytes = (s: string) => {
      const b64 = pad(s.replace(/-/g, '+').replace(/_/g, '/'));
      const bin = atob(b64);
      const bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      return bytes;
    };

    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
    );

    const valid = await crypto.subtle.verify('HMAC', key, b64urlToBytes(sig), enc.encode(data));
    if (!valid) return false;

    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(data)));
    if (!payload.ts || Date.now() - payload.ts > 30 * 24 * 60 * 60 * 1000) return false;
    return true;
  } catch {
    return false;
  }
}

export async function middleware(req: NextRequest) {
  const token = req.cookies.get('ec_session')?.value;
  const secret = process.env.SESSION_SECRET || '';
  const ok = await verifySessionEdge(token || '', secret);

  if (!ok) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', req.nextUrl.pathname);
    const res = NextResponse.redirect(url);
    res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
    return res;
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/team/:path*',
    '/account/:path*',
  ],
};
