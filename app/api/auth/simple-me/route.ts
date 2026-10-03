import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const token = cookies().get(AUTH_COOKIE)?.value;
  const ok = verifyAuthToken(token);
  if (!ok) return NextResponse.json({ auth: false }, { status: 401 });
  return NextResponse.json({ auth: true });
}
