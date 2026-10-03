import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export type SessionPayload = {
  userId: string;
  username: string;
  role: string;
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
  // timing-safe compare
  try {
    const a = Buffer.from(sig, 'base64url');
    const b = Buffer.from(expected, 'base64url');
    if (a.length !== b.length) return null;
    if (!crypto.timingSafeEqual(a, b)) return null;
  } catch {
    return null;
  }

  try {
    const p = JSON.parse(Buffer.from(data, 'base64url').toString());
    // 30-day expiry
    if (!p.ts || Date.now() - p.ts > 30 * 24 * 60 * 60 * 1000) return null;
    return p;
  } catch {
    return null;
  }
}
