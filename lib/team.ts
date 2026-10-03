/**
 * Team-only access control.
 * Only whitelisted emails can login. No public registration.
 *
 * ALLOWED_EMAILS env var — comma-separated list.
 * Example: "dipenzala1@gmail.com,certwinx@gmail.com,sales@company.com"
 */

export function isTeamMember(email: string): boolean {
  const raw = (process.env.ALLOWED_EMAILS || '').trim();
  if (!raw) {
    // If no whitelist configured, allow first admin
    return true; // Dev mode
  }
  const allowed = raw
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return allowed.includes(email.toLowerCase().trim());
}

export function getTeamList(): string[] {
  const raw = (process.env.ALLOWED_EMAILS || '').trim();
  if (!raw) return [];
  return raw.split(',').map((e) => e.trim()).filter(Boolean);
}

export function addTeamMember(current: string, email: string): string {
  const list = current.split(',').map((e) => e.trim()).filter(Boolean);
  const clean = email.trim().toLowerCase();
  if (!list.includes(clean)) list.push(clean);
  return list.join(',');
}

export function removeTeamMember(current: string, email: string): string {
  const clean = email.trim().toLowerCase();
  return current
    .split(',')
    .map((e) => e.trim())
    .filter((e) => e && e.toLowerCase() !== clean)
    .join(',');
}
