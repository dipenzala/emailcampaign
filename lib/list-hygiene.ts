import { checkEmailHygiene } from './spam-checker';
export type HygieneResult = {
  valid: any[];
  rejected: { email: string; reason: string }[];
  stats: { total: number; valid: number; roleAccounts: number; disposable: number; invalidFormat: number };
};
export function cleanList(rows: any[]): HygieneResult {
  const result: HygieneResult = { valid: [], rejected: [], stats: { total: rows.length, valid: 0, roleAccounts: 0, disposable: 0, invalidFormat: 0 } };
  const seen = new Set<string>();
  for (const row of rows) {
    const email = String(row.email || '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      result.rejected.push({ email, reason: 'INVALID_FORMAT' });
      result.stats.invalidFormat++;
      continue;
    }
    if (seen.has(email)) { result.rejected.push({ email, reason: 'DUPLICATE' }); continue; }
    seen.add(email);
    const hygiene = checkEmailHygiene(email);
    if (hygiene.isDisposable) { result.rejected.push({ email, reason: 'DISPOSABLE_DOMAIN' }); result.stats.disposable++; continue; }
    if (hygiene.isRoleAccount) result.stats.roleAccounts++;
    result.valid.push({ ...row, email, hygieneScore: hygiene.score, isRoleAccount: hygiene.isRoleAccount, isDisposable: false });
    result.stats.valid++;
  }
  return result;
}
