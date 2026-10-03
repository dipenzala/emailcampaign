import crypto from 'crypto';

const PASSWORD = 'DIPEN@3899';
const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
const COOKIE_NAME = 'ec_auth';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

export function checkPassword(input: string): boolean {
  return input === PASSWORD;
}

export function createAuthToken(): string {
  const payload = Buffer.from(JSON.stringify({ admin: true, ts: Date.now() })).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function verifyAuthToken(token?: string): boolean {
  if (!token) return false;
  const [payload, sig] = token.split('.');
  if (!payload || !sig) return false;
  const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  if (sig !== expected) return false;
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return data.admin === true;
  } catch { return false; }
}

export const AUTH_COOKIE = COOKIE_NAME;
export const AUTH_COOKIE_MAX_AGE = COOKIE_MAX_AGE;
