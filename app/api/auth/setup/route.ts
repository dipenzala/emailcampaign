import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { hashPassword } from '@/lib/password';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * One-time admin creation.
 * Call with POST body: { username, password, setupKey }
 * setupKey must match env var ADMIN_SETUP_KEY
 * Only works if NO users exist yet.
 */
export async function POST(req: Request) {
  const { username, password, setupKey } = await req.json();

  const expectedKey = process.env.ADMIN_SETUP_KEY || '';
  if (!expectedKey) {
    return NextResponse.json({ error: 'ADMIN_SETUP_KEY not configured' }, { status: 500 });
  }
  if (setupKey !== expectedKey) {
    return NextResponse.json({ error: 'Invalid setup key' }, { status: 403 });
  }

  const count = await prisma.user.count();
  if (count > 0) {
    return NextResponse.json({ error: 'Setup already completed. Users exist.' }, { status: 400 });
  }

  if (!username || username.length < 3) {
    return NextResponse.json({ error: 'Username min 3 chars' }, { status: 400 });
  }
  if (!password || password.length < 8) {
    return NextResponse.json({ error: 'Password min 8 chars' }, { status: 400 });
  }

  const user = await prisma.user.create({
    data: {
      username: username.trim().toLowerCase(),
      passwordHash: hashPassword(password),
      displayName: username,
      role: 'owner',
    },
  });

  return NextResponse.json({
    ok: true,
    user: { username: user.username, role: user.role },
    message: 'Admin created. You can now login at /login',
  });
}

// GET: check if setup needed
export async function GET() {
  const count = await prisma.user.count();
  return NextResponse.json({
    setupNeeded: count === 0,
    hasUsers: count > 0,
    hasSetupKey: !!(process.env.ADMIN_SETUP_KEY || ''),
  });
}
