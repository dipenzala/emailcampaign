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
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try {
    const p = JSON.parse(Buffer.from(data, 'base64url').toString());
    // 30 day expiry
    if (Date.now() - p.ts > 30 * 24 * 60 * 60 * 1000) return null;
    return p;
  } catch {
    return null;
  }
}
