import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession, hashToken } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list active sessions for current user
export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const list = await (prisma as any).session?.findMany?.({
    where: { userId: session.userId, revokedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { lastSeenAt: 'desc' },
    select: {
      id: true, deviceId: true, deviceName: true, ip: true,
      createdAt: true, lastSeenAt: true, expiresAt: true,
    },
  }) ?? [];

  const currentHash = token ? hashToken(token) : '';
  const current = await (prisma as any).session?.findUnique?.({
    where: { tokenHash: currentHash },
    select: { id: true },
  }).catch(() => null);

  return NextResponse.json({
    sessions: list.map((s: any) => ({
      ...s,
      isCurrent: s.id === current?.id,
    })),
  });
}

// DELETE: revoke a session (or all others)
export async function DELETE(req: Request) {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = await req.json().catch(() => ({}));
  const { id, all, exceptCurrent } = body;

  if (all === true) {
    // Revoke all sessions for this user
    const currentHash = token ? hashToken(token) : '';
    const current = await (prisma as any).session?.findUnique?.({
      where: { tokenHash: currentHash },
      select: { id: true },
    }).catch(() => null);

    if (exceptCurrent && current?.id) {
      await (prisma as any).session?.updateMany?.({
        where: { userId: session.userId, id: { not: current.id }, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      await (prisma as any).session?.updateMany?.({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return NextResponse.json({ ok: true, action: exceptCurrent ? 'others' : 'all' });
  }

  if (id) {
    await (prisma as any).session?.update?.({
      where: { id },
      data: { revokedAt: new Date() },
    }).catch(() => {});
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: 'id or all required' }, { status: 400 });
}
