import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyPassword } from '@/lib/password';
import { signSession } from '@/lib/session';
import { rateLimit, getClientIp } from '@/lib/rate-limit';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const ip = getClientIp(req);

  // Max 10 attempts per IP per 15 minutes
  const rl = rateLimit(`login:${ip}`, 10, 15 * 60 * 1000);
  if (!rl.ok) {
    return NextResponse.json(
      { error: `Too many attempts. Try again in ${rl.retryAfter}s.` },
      { status: 429, headers: { 'Retry-After': String(rl.retryAfter) } },
    );
  }

  const body = await req.json().catch(() => ({}));
  const { username, password } = body;

  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }

  const cleanUsername = String(username).trim().toLowerCase();

  const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (!user || !user.isActive) {
    // Audit log
    await prisma.auditLog.create({
      data: { action: 'LOGIN_FAILED', meta: { username: cleanUsername, ip, reason: 'no_user' } as any },
    }).catch(() => {});
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  if (!verifyPassword(password, user.passwordHash)) {
    await prisma.auditLog.create({
      data: { action: 'LOGIN_FAILED', meta: { username: cleanUsername, ip, reason: 'bad_password' } as any },
    }).catch(() => {});
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() },
  });

  await prisma.auditLog.create({
    data: { action: 'LOGIN_SUCCESS', meta: { username: cleanUsername, ip } as any },
  }).catch(() => {});

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
