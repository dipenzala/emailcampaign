import { NextResponse } from 'next/server';
import { getTeamList } from '@/lib/team';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const list = getTeamList();
  return NextResponse.json({ members: list });
}
