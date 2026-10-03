import crypto from 'crypto';

/**
 * Password hashing with Node's built-in scrypt (no external deps).
 * Format: scrypt$N$salt$hash
 */

const N = 16384;      // CPU/memory cost
const KEYLEN = 64;

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, KEYLEN, { N });
  return `scrypt$${N}$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  try {
    const [scheme, nStr, saltHex, hashHex] = stored.split('$');
    if (scheme !== 'scrypt') return false;
    const N = parseInt(nStr, 10);
    const salt = Buffer.from(saltHex, 'hex');
    const expected = Buffer.from(hashHex, 'hex');
    const actual = crypto.scryptSync(password, salt, expected.length, { N });
    return crypto.timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

export function generateRandomPassword(len = 16): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
  let out = '';
  const buf = crypto.randomBytes(len);
  for (let i = 0; i < len; i++) out += chars[buf[i] % chars.length];
  return out;
}
