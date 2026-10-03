import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
  return res;
}
