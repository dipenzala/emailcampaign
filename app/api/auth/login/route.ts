import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyPassword } from '@/lib/password';
import { signSession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { username, password } = await req.json();

  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }

  const cleanUsername = String(username).trim().toLowerCase();

  const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (!user || !user.isActive) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  if (!verifyPassword(password, user.passwordHash)) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() },
  });

  const token = signSession({
    userId: user.id,
    username: user.username,
    role: user.role,
    ts: Date.now(),
  });

  const res = NextResponse.json({
    ok: true,
    user: { username: user.username, role: user.role },
  });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
