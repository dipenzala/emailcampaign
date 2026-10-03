import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { token: string } }) {
  const email = Buffer.from(params.token, 'base64url').toString();
  if (!email) return NextResponse.json({ error: 'Invalid' }, { status: 400 });
  await prisma.suppressionList.upsert({ where: { email }, create: { email, reason: 'UNSUBSCRIBED' }, update: { reason: 'UNSUBSCRIBED' } });
  return new NextResponse(`<html><body style="font-family:sans-serif;padding:40px;text-align:center"><h1>✅ Unsubscribed</h1><p>${email}</p></body></html>`, { headers: { 'Content-Type': 'text/html' } });
}
