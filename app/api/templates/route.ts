import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list templates
export async function GET() {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const list = await prisma.emailTemplate.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        subject: true,
        description: true,
        category: true,
        isDefault: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    return NextResponse.json(list);
  } catch (err: any) {
    console.error('[templates GET]', err);
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// POST: create template
export async function POST(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { name, subject, html, description, category } = await req.json();
    if (!name || !html) {
      return NextResponse.json({ error: 'name and html required' }, { status: 400 });
    }

    const tpl = await prisma.emailTemplate.create({
      data: {
        name: String(name),
        subject: subject ? String(subject) : null,
        html: String(html),
        description: description ? String(description) : null,
        category: category ? String(category) : null,
        createdBy: session.email || session.username || null,
      },
    });

    return NextResponse.json({ ok: true, template: tpl });
  } catch (err: any) {
    console.error('[templates POST]', err);
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// DELETE: remove template
export async function DELETE(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const url = new URL(req.url);
    const id = url.searchParams.get('id');
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    await prisma.emailTemplate.delete({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}
