import dns from 'dns/promises';

/**
 * Universal email validator with MX record check.
 * Uses plain object types (no namespace types) — build-safe.
 */

// ---------- Level 1: Syntax ----------
export function isValidEmailSyntax(e: string): boolean {
  if (!e) return false;
  const clean = e.trim().toLowerCase();
  return /^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/.test(clean);
}

// ---------- Level 2: Disposable domain block ----------
const DISPOSABLE_DOMAINS = new Set([
  'tempmail.com', 'guerrillamail.com', 'mailinator.com', '10minutemail.com',
  'throwaway.email', 'trashmail.com', 'yopmail.com', 'sharklasers.com',
  'temp-mail.org', 'getnada.com', 'fakeinbox.com', 'maildrop.cc',
  'dispostable.com', 'mailnesia.com', 'spamgourmet.com', 'mytemp.email',
  'tempr.email', 'tempmail.net', 'throwawaymail.com', 'mintemail.com',
  'mailtemp.info', 'guerrillamail.info', 'guerrillamail.biz', 'grr.la',
  'spam4.me', 'trbvm.com', 'vomoto.com', 'yopmail.fr', 'yopmail.net',
]);

export function isDisposableEmail(email: string): boolean {
  const domain = email.toLowerCase().split('@')[1] || '';
  return DISPOSABLE_DOMAINS.has(domain);
}

// ---------- Level 3: MX record lookup (cached) ----------
type MxCacheEntry = { hasMx: boolean; records: string[]; expiresAt: number };
const mxCache = new Map<string, MxCacheEntry>();
const MX_CACHE_TTL = 60 * 60 * 1000; // 1 hour

// Plain type (no dns.MxRecord namespace reference — avoids TS build issues)
type SimpleMxRecord = { exchange: string; priority: number };

export async function domainHasMx(domain: string): Promise<{ hasMx: boolean; records: string[] }> {
  const clean = domain.toLowerCase().trim();

  const cached = mxCache.get(clean);
  if (cached && cached.expiresAt > Date.now()) {
    return { hasMx: cached.hasMx, records: cached.records };
  }

  try {
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('DNS timeout')), 4000)
    );

    // Cast to plain type — no namespace reference
    const records = (await Promise.race([
      dns.resolveMx(clean),
      timeout,
    ])) as unknown as SimpleMxRecord[];

    const hasMx = Array.isArray(records) && records.length > 0;
    const hosts = hasMx
      ? records
          .sort((a, b) => (a.priority || 0) - (b.priority || 0))
          .map((r) => r.exchange)
          .filter(Boolean)
      : [];

    mxCache.set(clean, { hasMx, records: hosts, expiresAt: Date.now() + MX_CACHE_TTL });
    return { hasMx, records: hosts };
  } catch {
    mxCache.set(clean, { hasMx: false, records: [], expiresAt: Date.now() + MX_CACHE_TTL });
    return { hasMx: false, records: [] };
  }
}

// ---------- Full validation ----------
export type ValidationReason = 'OK' | 'INVALID_SYNTAX' | 'DISPOSABLE' | 'NO_MX';

export type FullValidation = {
  valid: boolean;
  reason: ValidationReason;
  domain: string;
  mxRecords?: string[];
};

export async function validateEmailFull(email: string): Promise<FullValidation> {
  const clean = email.trim().toLowerCase();

  if (!isValidEmailSyntax(clean)) {
    return { valid: false, reason: 'INVALID_SYNTAX', domain: '' };
  }

  const domain = clean.split('@')[1] || '';

  if (isDisposableEmail(clean)) {
    return { valid: false, reason: 'DISPOSABLE', domain };
  }

  const { hasMx, records } = await domainHasMx(domain);
  if (!hasMx) {
    return { valid: false, reason: 'NO_MX', domain };
  }

  return { valid: true, reason: 'OK', domain, mxRecords: records };
}

// ---------- Batch domain validation ----------
export async function validateDomains(
  domains: string[],
  concurrency = 20,
): Promise<Map<string, boolean>> {
  const results = new Map<string, boolean>();
  const unique = Array.from(new Set(domains.map((d) => d.toLowerCase().trim())));
  const queue = [...unique];
  let active = 0;

  return new Promise((resolve) => {
    const next = () => {
      if (queue.length === 0 && active === 0) return resolve(results);
      while (active < concurrency && queue.length > 0) {
        const domain = queue.shift()!;
        active++;
        domainHasMx(domain)
          .then((r) => results.set(domain, r.hasMx))
          .catch(() => results.set(domain, false))
          .finally(() => { active--; next(); });
      }
    };
    next();
  });
}

// ---------- Backwards compat ----------
export function isValidEmail(e: string): boolean {
  return isValidEmailSyntax(e);
}
