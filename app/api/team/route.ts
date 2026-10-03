import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession, hashPassword } from '@/lib/session';
import { randomBytes } from 'crypto';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list team members
export async function GET() {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        name: true,
        role: true,
        isActive: true,
        lastLoginAt: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ users });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// POST: create new team member
export async function POST(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const { username, password, role } = await req.json();
    if (!username || !password) {
      return NextResponse.json({ error: 'username + password required' }, { status: 400 });
    }
    if (String(password).length < 8) {
      return NextResponse.json({ error: 'Password min 8 chars' }, { status: 400 });
    }

    const cleanUsername = String(username).toLowerCase().trim();

    const exists = await prisma.user.findUnique({ where: { username: cleanUsername } });
    if (exists) {
      return NextResponse.json({ error: 'Username taken' }, { status: 409 });
    }

    const user = await prisma.user.create({
      data: {
        username: cleanUsername,
        passwordHash: hashPassword(password),
        displayName: cleanUsername,
        name: cleanUsername,
        role: role || 'user',
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ ok: true, user });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// PUT: update user role / active status
export async function PUT(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const { id, role, isActive } = await req.json();
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    const data: any = {};
    if (typeof role === 'string') data.role = role;
    if (typeof isActive === 'boolean') data.isActive = isActive;

    const user = await prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
      },
    });

    return NextResponse.json({ ok: true, user });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// DELETE: remove team member
export async function DELETE(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const url = new URL(req.url);
    const id = url.searchParams.get('id');
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    await prisma.user.delete({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}
