import crypto from 'crypto';
let _key: Buffer | null = null;
function getKey(): Buffer {
  if (_key) return _key;
  const raw = (process.env.TOKEN_ENCRYPTION_KEY || '').trim();
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be 64 hex chars (got ' + raw.length + ')');
  }
  _key = Buffer.from(raw, 'hex');
  return _key;
}
export function encrypt(plain: string): string {
  const key = getKey();
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
}
export function decrypt(payload: string): string {
  const key = getKey();
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const d = crypto.createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(data), d.final()]).toString('utf8');
}
