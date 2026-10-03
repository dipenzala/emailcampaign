import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';
import { isTeamMember } from '@/lib/team';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { email, password } = await req.json();

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  }

  const cleanEmail = String(email).toLowerCase().trim();

  // Team-only check
  if (!isTeamMember(cleanEmail)) {
    return NextResponse.json(
      { error: 'Access denied. This platform is invite-only for team members.' },
      { status: 403 }
    );
  }

  // Save to users table
  try {
    await prisma.user.upsert({
      where: { email: cleanEmail },
      create: { email: cleanEmail, name: cleanEmail.split('@')[0] },
      update: {},
    });
  } catch {}

  const token = signSession({
    email: cleanEmail,
    name: cleanEmail.split('@')[0],
    ts: Date.now(),
  });

  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
