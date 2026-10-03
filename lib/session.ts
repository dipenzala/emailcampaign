import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
export const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

export type SessionPayload = {
  userId: string;
  username: string;
  role: string;
  deviceId: string;
  ts: number;
};

export function signSession(payload: SessionPayload): string {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): SessionPayload | null {
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const [data, sig] = parts;
  if (!data || !sig) return null;

  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  try {
    const a = Buffer.from(sig, 'base64url');
    const b = Buffer.from(expected, 'base64url');
    if (a.length !== b.length) return null;
    if (!crypto.timingSafeEqual(a, b)) return null;
  } catch {
    return null;
  }

  try {
    const p = JSON.parse(Buffer.from(data, 'base64url').toString()) as SessionPayload;
    if (!p.ts || Date.now() - p.ts > SESSION_TTL_MS) return null;
    return p;
  } catch {
    return null;
  }
}

/**
 * Hash the raw token to store in DB (never store raw session).
 */
export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}
