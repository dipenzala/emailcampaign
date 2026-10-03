import crypto from 'crypto';

/**
 * Generate a random device ID on first login.
 * Stored in browser localStorage — used to bind session to device.
 */
export function generateDeviceId(): string {
  return crypto.randomBytes(16).toString('hex');
}

export function generateDeviceName(ua?: string): string {
  if (!ua) return 'Unknown Device';
  if (/iPhone/i.test(ua)) return 'iPhone';
  if (/iPad/i.test(ua)) return 'iPad';
  if (/Android/i.test(ua)) return 'Android Device';
  if (/Macintosh/i.test(ua)) return 'Mac';
  if (/Windows/i.test(ua)) return 'Windows PC';
  if (/Linux/i.test(ua)) return 'Linux';
  return 'Browser';
}
