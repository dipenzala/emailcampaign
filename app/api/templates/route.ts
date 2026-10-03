import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list templates
export async function GET() {
  try {
    const list = await prisma.emailTemplate?.findMany?.({ orderBy: { createdAt: 'desc' } }) ?? [];
    return NextResponse.json(list);
  } catch {
    return NextResponse.json([]);
  }
}

// POST: save template
export async function POST(req: Request) {
  const { name, subject, html } = await req.json();
  if (!name || !html) return NextResponse.json({ error: 'name and html required' }, { status: 400 });
  try {
    const t = await (prisma as any).emailTemplate?.create?.({
      data: { name, subject: subject || '', html },
    });
    return NextResponse.json({ ok: true, template: t });
  } catch (e: any) {
    return NextResponse.json({ error: 'Template table not migrated', detail: e.message }, { status: 500 });
  }
}
