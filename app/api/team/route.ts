import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession } from '@/lib/session';
import { hashPassword, generateRandomPassword } from '@/lib/password';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

async function requireAdmin() {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session || session.role !== 'owner') return null;
  return session;
}

// GET: list team members
export async function GET() {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: {
      id: true, username: true, displayName: true,
      role: true, isActive: true, lastLoginAt: true, createdAt: true,
    },
  });
  return NextResponse.json({ members: users });
}

// POST: add new member
export async function POST(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { username, password, displayName, role } = await req.json();
  if (!username || username.length < 3) {
    return NextResponse.json({ error: 'Username must be at least 3 characters' }, { status: 400 });
  }
  const cleanUsername = String(username).trim().toLowerCase();

  const finalPassword = password && password.length >= 6
    ? password
    : generateRandomPassword(14);

  const exists = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (exists) return NextResponse.json({ error: 'Username already exists' }, { status: 400 });

  const user = await prisma.user.create({
    data: {
      username: cleanUsername,
      passwordHash: hashPassword(finalPassword),
      displayName: displayName || cleanUsername,
      role: role === 'owner' ? 'owner' : 'member',
    },
  });

  return NextResponse.json({
    ok: true,
    user: { id: user.id, username: user.username, role: user.role },
    password: finalPassword, // Show once to admin
  });
}

// PATCH: update member (reset password, toggle active, change role)
export async function PATCH(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id, action, newPassword, role, isActive } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const data: any = {};
  if (action === 'reset-password') {
    const pwd = newPassword && newPassword.length >= 6 ? newPassword : generateRandomPassword(14);
    data.passwordHash = hashPassword(pwd);
    await prisma.user.update({ where: { id }, data });
    return NextResponse.json({ ok: true, password: pwd });
  }
  if (typeof role === 'string') data.role = role === 'owner' ? 'owner' : 'member';
  if (typeof isActive === 'boolean') data.isActive = isActive;

  await prisma.user.update({ where: { id }, data });
  return NextResponse.json({ ok: true });
}

// DELETE: remove member
export async function DELETE(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  // Prevent deleting self
  if (id === session.userId) {
    return NextResponse.json({ error: 'Cannot delete yourself' }, { status: 400 });
  }

  await prisma.user.delete({ where: { id } });
  return NextResponse.json({ ok: true });
}
