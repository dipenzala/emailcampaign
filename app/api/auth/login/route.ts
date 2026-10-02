import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { email, name } = await req.json();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  }
  const cleanEmail = String(email).toLowerCase().trim();
  try {
    await prisma.user.upsert({
      where: { email: cleanEmail },
      create: { email: cleanEmail, name: name || cleanEmail.split('@')[0] },
      update: {},
    });
  } catch { /* DB not ready */ }
  const token = signSession({ email: cleanEmail, name: name || cleanEmail.split('@')[0], ts: Date.now() });
  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax', path: '/', maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
