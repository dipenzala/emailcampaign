import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifySession } from '@/lib/session';
export const dynamic = 'force-dynamic';
export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const user = verifySession(token);
  if (!user) return NextResponse.json({ user: null }, { status: 401 });
  return NextResponse.json({ user: { email: user.email, name: user.name } });
}
