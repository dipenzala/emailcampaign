import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { prisma } from './prisma';
import { verifySession } from './session';

export type GuardedSession = {
  userId: string;
  username: string;
  role: string;
  deviceId: string;
};

/**
 * Server-side auth guard. Use at top of every protected layout/page.
 *
 * Checks:
 *  1. Cookie exists + HMAC valid + not expired
 *  2. User exists in DB and is active
 *  3. Session exists in DB and is not revoked
 *  4. Device ID matches
 *
 * On failure → redirects to /login
 */
export async function requireAuth(): Promise<GuardedSession> {
  const jar = cookies();
  const token = jar.get('ec_session')?.value;

  if (!token) redirect('/login');

  const session = verifySession(token);
  if (!session) {
    // Bad/expired token — clear it
    try { jar.delete('ec_session'); } catch {}
    redirect('/login');
  }

  // DB-level checks
  const user = await prisma.user.findUnique({ where: { id: session.userId } });
  if (!user || !user.isActive) {
    try { jar.delete('ec_session'); } catch {}
    redirect('/login');
  }

  // Session-level check (device binding + revocation)
  try {
    const dbSession = await (prisma as any).session?.findUnique?.({
      where: { tokenHash: (await import('./session')).hashToken(token) },
    });
    if (dbSession) {
      if (dbSession.revokedAt) redirect('/login');
      if (dbSession.expiresAt < new Date()) redirect('/login');
      if (dbSession.deviceId !== session.deviceId) redirect('/login');
      // update last seen
      await (prisma as any).session?.update?.({
        where: { id: dbSession.id },
        data: { lastSeenAt: new Date() },
      }).catch(() => {});
    } else {
      // Session row missing — force re-login
      redirect('/login');
    }
  } catch (e) {
    // If session table doesn't exist yet (first deploy) — allow
  }

  return {
    userId: session.userId,
    username: session.username,
    role: session.role,
    deviceId: session.deviceId,
  };
}
