import { NextResponse } from 'next/server';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { subject, html, fromEmail } = await req.json();
  if (!subject || !html) return NextResponse.json({ error: 'subject and html required' }, { status: 400 });
  return NextResponse.json(checkEmail({ subject, html, fromEmail: fromEmail || 'noreply@example.com' }));
}
