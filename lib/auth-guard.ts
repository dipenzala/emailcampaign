import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { prisma } from './prisma';
import { verifySession, type SessionPayload } from './session';

export function getSession(): SessionPayload | null {
  const token = cookies().get('ec_session')?.value;
  return verifySession(token);
}

export function requireAuth(): SessionPayload {
  const s = getSession();
  if (!s) redirect('/login');
  return s;
}

export function requireOwner(): SessionPayload {
  const s = requireAuth();
  if (s.role !== 'owner') redirect('/dashboard');
  return s;
}

export async function loadCurrentUser(): Promise<any | null> {
  const s = getSession();
  if (!s) return null;
  try {
    if (s.userId) {
      const u = await prisma.user.findUnique({ where: { id: String(s.userId) } });
      if (u) return u;
    }
    if (s.email) {
      const u = await prisma.user.findUnique({ where: { email: String(s.email) } });
      if (u) return u;
    }
    if (s.username) {
      const u = await prisma.user.findUnique({ where: { username: String(s.username) } });
      if (u) return u;
    }
  } catch { return null; }
  return null;
}

export async function assertSession(): Promise<SessionPayload> {
  const s = requireAuth();
  if (s.role === 'owner') {
    try {
      const u = await loadCurrentUser();
      if (u && (u as any).isActive === false) {
        try { (cookies() as any).delete?.('ec_session'); } catch {}
        redirect('/login');
      }
    } catch {}
  }
  return s;
}

// Safe accessors — explicit string casts (never undefined)
export const Session = {
  userId: (s: SessionPayload | null): string => String(s?.userId ?? s?.id ?? ''),
  email: (s: SessionPayload | null): string => String(s?.email ?? ''),
  username: (s: SessionPayload | null): string => String(s?.username ?? ''),
  name: (s: SessionPayload | null): string => String(s?.name ?? s?.displayName ?? ''),
  role: (s: SessionPayload | null): string => String(s?.role ?? 'user'),
  deviceId: (s: SessionPayload | null): string => String(s?.deviceId ?? ''),
  isOwner: (s: SessionPayload | null): boolean => s?.role === 'owner',
};
