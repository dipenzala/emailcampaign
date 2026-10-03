import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyPassword } from '@/lib/password';
import { signSession, hashToken, SESSION_TTL_MS } from '@/lib/session';
import { generateDeviceName } from '@/lib/device';
import { rateLimit, getClientIp } from '@/lib/rate-limit';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const ip = getClientIp(req);

  // Rate limit: 10 attempts per IP per 15 min
  const rl = rateLimit(`login:${ip}`, 10, 15 * 60 * 1000);
  if (!rl.ok) {
    return NextResponse.json(
      { error: `Too many attempts. Try again in ${rl.retryAfter}s.` },
      { status: 429, headers: { 'Retry-After': String(rl.retryAfter) } },
    );
  }

  const body = await req.json().catch(() => ({}));
  const { username, password, deviceId } = body;

  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }
  if (!deviceId || typeof deviceId !== 'string' || deviceId.length < 16) {
    return NextResponse.json({ error: 'Device ID required. Reload the page.' }, { status: 400 });
  }

  const cleanUsername = String(username).trim().toLowerCase();
  const ua = req.headers.get('user-agent') || '';

  const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (!user || !user.isActive) {
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

  // Sign session with device binding
  const token = signSession({
    userId: user.id,
    username: user.username,
    role: user.role,
    deviceId,
    ts: Date.now(),
  });

  const tokenHash = hashToken(token);

  // Revoke any prior session with same deviceId (login = new session)
  await (prisma as any).session?.updateMany?.({
    where: { userId: user.id, deviceId, revokedAt: null },
    data: { revokedAt: new Date() },
  }).catch(() => {});

  // Store session in DB
  await (prisma as any).session?.create?.({
    data: {
      userId: user.id,
      deviceId,
      deviceName: generateDeviceName(ua),
      ip,
      userAgent: ua.slice(0, 500),
      tokenHash,
      expiresAt: new Date(Date.now() + SESSION_TTL_MS),
    },
  }).catch((e: any) => console.error('session create error:', e.message));

  await prisma.auditLog.create({
    data: { action: 'LOGIN_SUCCESS', meta: { username: cleanUsername, ip, deviceId } as any },
  }).catch(() => {});

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
