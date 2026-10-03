import crypto from 'crypto';
const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export type SessionPayload = {
  userId?: string;
  id?: string;
  email?: string;
  username?: string;
  name?: string;
  displayName?: string;
  role?: string;
  isActive?: boolean;
  deviceId?: string;
  ts: number;
  exp?: number;
  [key: string]: any;
};

export function signSession(p: SessionPayload): string {
  const data = Buffer.from(JSON.stringify(p)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): SessionPayload | null {
  if (!token) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try { return JSON.parse(Buffer.from(data, 'base64url').toString()); } catch { return null; }
}

export function hashToken(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

export function generateToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}

export function hashPassword(password: string, salt?: string): string {
  const s = salt ?? crypto.randomBytes(16).toString('hex');
  const h = crypto.pbkdf2Sync(password, s, 100_000, 64, 'sha512').toString('hex');
  return `${s}:${h}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  try {
    const [s, h] = stored.split(':');
    if (!s || !h) return false;
    const c = crypto.pbkdf2Sync(password, s, 100_000, 64, 'sha512').toString('hex');
    return crypto.timingSafeEqual(Buffer.from(c), Buffer.from(h));
  } catch { return false; }
}
