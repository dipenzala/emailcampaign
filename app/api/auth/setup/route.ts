import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession, hashPassword } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { username, password } = await req.json();
    if (!username || !password) {
      return NextResponse.json({ error: 'username + password required' }, { status: 400 });
    }
    if (String(password).length < 8) {
      return NextResponse.json({ error: 'Password min 8 characters' }, { status: 400 });
    }

    // Check if any owner exists
    const ownerExists = await prisma.user.findFirst({ where: { role: 'owner' } });
    if (ownerExists) {
      return NextResponse.json({ error: 'Owner already exists. Use invite flow.' }, { status: 403 });
    }

    const cleanUsername = String(username).trim().toLowerCase();
    const user = await prisma.user.create({
      data: {
        username: cleanUsername,
        passwordHash: hashPassword(password),
        displayName: cleanUsername,
        name: cleanUsername,
        role: 'owner',
      },
    });

    const token = signSession({
      username: user.username || '',
      name: user.displayName || user.username || '',
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
  } catch (err: any) {
    return NextResponse.json({ error: 'Setup failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
