import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { email, username, name, password } = await req.json();

    // Email login (existing flow)
    if (email) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
        return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
      }
      const cleanEmail = String(email).toLowerCase().trim();
      try {
        await prisma.user.upsert({
          where: { email: cleanEmail },
          create: { email: cleanEmail, name: name || cleanEmail.split('@')[0], role: 'user' },
          update: {},
        });
      } catch {}
      const token = signSession({
        email: cleanEmail,
        name: name || cleanEmail.split('@')[0],
        role: 'user',
        ts: Date.now(),
      });
      const res = NextResponse.json({ ok: true, email: cleanEmail, role: 'user' });
      res.cookies.set('ec_session', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 * 24 * 30,
      });
      return res;
    }

    // Username login (invite-only team)
    if (username && password) {
      const cleanUsername = String(username).toLowerCase().trim();
      const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
      if (!user) return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });

      const { verifyPassword } = await import('@/lib/session');
      if (!user.passwordHash || !verifyPassword(password, user.passwordHash)) {
        return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
      }

      const token = signSession({
        username: user.username || '',
        name: user.displayName || user.name || user.username || '',
        role: user.role,
        ts: Date.now(),
      });
      const res = NextResponse.json({ ok: true, username: user.username, role: user.role });
      res.cookies.set('ec_session', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 * 24 * 30,
      });
      return res;
    }

    return NextResponse.json({ error: 'Missing credentials' }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: 'Login failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
