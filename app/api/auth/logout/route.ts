import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { hashToken } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST() {
  const jar = cookies();
  const token = jar.get('ec_session')?.value;

  if (token) {
    try {
      await (prisma as any).session?.updateMany?.({
        where: { tokenHash: hashToken(token) },
        data: { revokedAt: new Date() },
      });
    } catch {}
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
  return res;
}
