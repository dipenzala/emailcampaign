export function isValidEmail(e: string) {
  if (!e) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());
}
