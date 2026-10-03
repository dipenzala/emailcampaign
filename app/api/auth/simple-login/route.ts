import { NextResponse } from 'next/server';
import { checkPassword, createAuthToken, AUTH_COOKIE, AUTH_COOKIE_MAX_AGE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { password } = await req.json();
    if (!password) return NextResponse.json({ error: 'Password required' }, { status: 400 });
    if (!checkPassword(password)) return NextResponse.json({ error: 'Wrong password' }, { status: 401 });
    const token = createAuthToken();
    const res = NextResponse.json({ ok: true });
    res.cookies.set(AUTH_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: AUTH_COOKIE_MAX_AGE,
    });
    return res;
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'Login failed' }, { status: 500 });
  }
}
