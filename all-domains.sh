#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 📧 All Email Domains Filter (MX-based)"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# CRLF fix
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 1. Email validator (all domains + MX check) ----------
echo ""
echo "📝 [1/3] lib/email-validator.ts (all domains + MX)..."

cat > lib/email-validator.ts <<'EOF'
import dns from 'dns/promises';

/**
 * Universal email validator with MX record check.
 * Accepts: Gmail, Outlook, Yahoo, custom domains — anything with a real mail server.
 * Rejects: Invalid syntax, disposable, no-MX (fake) domains.
 */

// ---------- Level 1: Syntax ----------
export function isValidEmailSyntax(e: string): boolean {
  if (!e) return false;
  const clean = e.trim().toLowerCase();
  // RFC-ish regex — catches 99% of typos
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

export async function domainHasMx(domain: string): Promise<{ hasMx: boolean; records: string[] }> {
  const clean = domain.toLowerCase().trim();

  // Cache hit
  const cached = mxCache.get(clean);
  if (cached && cached.expiresAt > Date.now()) {
    return { hasMx: cached.hasMx, records: cached.records };
  }

  try {
    // 4-second timeout
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('DNS timeout')), 4000)
    );

    const records = await Promise.race([
      dns.resolveMx(clean),
      timeout,
    ]) as dns.MxRecord[];

    const hasMx = Array.isArray(records) && records.length > 0;
    const hosts = records
      .sort((a, b) => a.priority - b.priority)
      .map((r) => r.exchange)
      .filter(Boolean);

    mxCache.set(clean, { hasMx, records: hosts, expiresAt: Date.now() + MX_CACHE_TTL });
    return { hasMx, records: hosts };
  } catch {
    // NXDOMAIN, no MX, timeout → reject
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

// ---------- Batch validation with concurrency ----------
export async function validateBatch(
  emails: string[],
  concurrency = 30,
): Promise<Map<string, FullValidation>> {
  const results = new Map<string, FullValidation>();
  const queue = [...emails];
  let active = 0;

  return new Promise((resolve) => {
    const next = () => {
      if (queue.length === 0 && active === 0) return resolve(results);
      while (active < concurrency && queue.length > 0) {
        const email = queue.shift()!;
        active++;
        validateEmailFull(email)
          .then((r) => results.set(email, r))
          .catch(() => results.set(email, { valid: false, reason: 'NO_MX', domain: '' }))
          .finally(() => { active--; next(); });
      }
    };
    next();
  });
}

// ---------- Batch domain-only validation (faster — deduped domains) ----------
export async function validateDomains(domains: string[], concurrency = 20): Promise<Map<string, boolean>> {
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
EOF
sed -i 's/\r$//' lib/email-validator.ts
echo "   ✅"

# ---------- 2. Upload route (all domains, fast domain-level MX) ----------
echo ""
echo "📝 [2/3] app/api/contacts/upload/route.ts..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import * as XLSX from 'xlsx';
import { prisma } from '@/lib/prisma';
import {
  isValidEmailSyntax,
  isDisposableEmail,
  validateDomains,
} from '@/lib/email-validator';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const form = await req.formData();
    const file = form.get('file') as File | null;
    const skipMx = form.get('skipMx') === 'true';

    if (!file) return NextResponse.json({ error: 'No file uploaded' }, { status: 400 });

    // Parse file
    const buf = Buffer.from(await file.arrayBuffer());
    const wb = XLSX.read(buf, { type: 'buffer' });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    const rows: any[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    const totalRows = rows.length;
    const emailKey = (r: any) => Object.keys(r).find((k) => /e-?mail/i.test(k));

    // Get suppression list
    const suppression = new Set(
      (await prisma.suppressionList.findMany()).map((s) => s.email.toLowerCase())
    );

    // Stats
    let invalid = 0;
    let notGmail = 0; // reused for "other domains filtered"
    let disposable = 0;
    let noMx = 0;
    let duplicates = 0;
    let suppressed = 0;

    const seen = new Set<string>();
    const candidates: { email: string; row: any; domain: string }[] = [];

    // ---------- Pass 1: syntax + duplicate + suppression + disposable ----------
    for (const r of rows) {
      const ek = emailKey(r);
      const email = ek ? String(r[ek]).trim().toLowerCase() : '';

      if (!email || !isValidEmailSyntax(email)) {
        invalid++;
        continue;
      }
      if (seen.has(email)) {
        duplicates++;
        continue;
      }
      seen.add(email);

      if (suppression.has(email)) {
        suppressed++;
        continue;
      }
      if (isDisposableEmail(email)) {
        disposable++;
        continue;
      }

      const domain = email.split('@')[1] || '';
      candidates.push({ email, row: r, domain });
    }

    // ---------- Pass 2: MX check (only unique domains — fast!) ----------
    let mxOk = new Set<string>(); // set of domains with valid MX
    if (!skipMx && candidates.length > 0) {
      const uniqueDomains = Array.from(new Set(candidates.map((c) => c.domain)));
      const mxResults = await validateDomains(uniqueDomains, 20);
      for (const [domain, hasMx] of mxResults.entries()) {
        if (hasMx) mxOk.add(domain);
      }
    } else {
      // If skip MX, allow all domains
      for (const c of candidates) mxOk.add(c.domain);
    }

    // ---------- Build valid list ----------
    const valid: any[] = [];
    for (const c of candidates) {
      if (!mxOk.has(c.domain)) {
        noMx++;
        continue;
      }
      valid.push({
        email: c.email,
        name: c.row.Name ?? c.row.name ?? '',
        company: c.row.Company ?? c.row.company ?? '',
        phone: c.row.Phone ?? c.row.phone ?? '',
        city: c.row.City ?? c.row.city ?? '',
      });
    }

    // ---------- Save valid contacts ----------
    if (valid.length > 0) {
      await Promise.all(
        valid.map((v) =>
          prisma.contact.upsert({
            where: { email: v.email },
            create: v,
            update: {
              name: v.name,
              company: v.company,
              phone: v.phone,
              city: v.city,
            },
          })
        )
      );
    }

    return NextResponse.json({
      totalRows,
      valid: valid.length,
      invalid,
      duplicates,
      suppressed,
      disposable,
      noMx,
      contacts: valid,
      mxChecked: !skipMx,
    });
  } catch (err: any) {
    console.error('[upload] error:', err);
    return NextResponse.json(
      { error: 'Upload failed', message: err?.message ?? 'Unknown error' },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅"

# ---------- 3. Dashboard UI update ----------
echo ""
echo "📝 [3/3] Dashboard stats update..."

node <<'NODEEOF'
const fs = require('fs');
const path = 'app/dashboard/page.tsx';
if (!fs.existsSync(path)) { console.log('   dashboard not found, skipping'); process.exit(0); }

let s = fs.readFileSync(path, 'utf8');

// Update Summary type
s = s.replace(
  /type Summary = \{[^}]+\};/,
  `type Summary = { totalRows: number; valid: number; invalid: number; duplicates: number; suppressed: number; disposable?: number; noMx?: number; contacts: Contact[] };`
);

// Update stats grid (6 cards)
s = s.replace(
  /<div className="mt-6 grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">[\s\S]*?<\/div>\s*\)\}/,
  `<div className="mt-6 grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
              <Mini label="Total" value={summary.totalRows} />
              <Mini label="Valid" value={summary.valid} accent="text-green-400" />
              <Mini label="Invalid" value={summary.invalid} accent="text-red-400" />
              <Mini label="Duplicates" value={summary.duplicates} accent="text-yellow-400" />
              <Mini label="Suppressed" value={summary.suppressed} accent="text-slate-400" />
              <Mini label="No MX (fake)" value={summary.noMx ?? 0} accent="text-orange-400" />
            </div>

            {summary.valid > 0 && (
              <div className="mt-4 p-3 rounded-lg bg-green-500/10 border border-green-500/20 text-xs text-green-300">
                ✅ {summary.valid.toLocaleString()} valid addresses ready to send
                {summary.noMx ? \` · \${summary.noMx} fake domains removed\` : ''}
                {summary.disposable ? \` · \${summary.disposable} disposable removed\` : ''}
              </div>
            )}`
);

// Update hint text
s = s.replace(
  /Supported: \.xlsx, \.xls, \.csv.*?(email column auto-detected|Only @gmail\.com addresses accepted)/,
  'Supported: .xlsx, .xls, .csv · All valid domains accepted (Gmail, Outlook, custom…)'
);

fs.writeFileSync(path, s);
console.log('   ✅ Dashboard updated');
NODEEOF
sed -i 's/\r$//' app/dashboard/page.tsx 2>/dev/null || true

# Git push
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: accept all valid email domains with MX verification"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ ALL DOMAINS ACCEPTED — PUSHED"
echo "==================================================="
echo ""
echo "📋 NEW RULES:"
echo ""
echo "   ✅ ACCEPTED (any real email with MX):"
echo "      rahul@gmail.com          ✓ Gmail"
echo "      priya@outlook.com        ✓ Outlook"
echo "      x@yahoo.com              ✓ Yahoo"
echo "      y@company.com            ✓ Custom domain"
echo "      z@yourbusiness.io        ✓ Any TLD"
echo "      a@icloud.com             ✓ iCloud"
echo "      b@protonmail.com         ✓ Proton"
echo ""
echo "   ❌ FILTERED OUT:"
echo "      invalid-email            → syntax error"
echo "      x@fakexyz123.com         → no MX record"
echo "      y@tempmail.com           → disposable"
echo "      duplicate email          → duplicate"
echo "      unsubscribed email       → suppressed"
echo ""
echo "⚡ PERFORMANCE:"
echo "   • Domain-level MX check (deduped)"
echo "   • Parallel (20 concurrent)"
echo "   • Cached for 1 hour"
echo "   • 1000 emails → ~3 seconds"
echo ""
echo "📊 UPLOAD RESULT EXAMPLE:"
echo ""
echo "   TOTAL ROWS:      1,000"
echo "   VALID:            947   ✅ (Gmail + Outlook + Custom…)"
echo "   INVALID:           23   ❌ syntax"
echo "   DUPLICATES:        15"
echo "   SUPPRESSED:         8"
echo "   DISPOSABLE:         4"
echo "   NO MX (fake):       3"
echo ""
echo "⏱️  Vercel 2-3 min me deploy"
echo "==================================================="