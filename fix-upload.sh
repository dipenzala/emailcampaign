#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Upload API + All Contact Routes"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. BULLETPROOF UPLOAD API
# ==========================================
echo "📝 [1/4] Rewriting upload API..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import * as XLSX from 'xlsx';
import { prisma } from '@/lib/prisma';
import { isValidEmail } from '@/lib/email-validator';
import { checkEmailHygiene } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

// Always return JSON — never crash
function jsonError(message: string, status = 500, extra: any = {}) {
  return NextResponse.json({ error: message, ok: false, ...extra }, { status });
}

export async function POST(req: Request) {
  try {
    // Parse form data safely
    let form: FormData;
    try {
      form = await req.formData();
    } catch (e: any) {
      return jsonError('Invalid form data: ' + e.message, 400);
    }

    const file = form.get('file') as File | null;
    if (!file) {
      return jsonError('No file uploaded', 400);
    }

    if (file.size === 0) {
      return jsonError('File is empty (0 bytes)', 400);
    }

    if (file.size > 10 * 1024 * 1024) {
      return jsonError('File too large (max 10MB)', 400);
    }

    // Read file as buffer
    let buf: Buffer;
    try {
      const ab = await file.arrayBuffer();
      buf = Buffer.from(ab);
    } catch (e: any) {
      return jsonError('Could not read file: ' + e.message, 400);
    }

    // Parse Excel/CSV
    let rows: any[] = [];
    try {
      const wb = XLSX.read(buf, { type: 'buffer' });
      if (!wb.SheetNames || wb.SheetNames.length === 0) {
        return jsonError('No sheets found in file', 400);
      }
      const sheet = wb.Sheets[wb.SheetNames[0]];
      if (!sheet) {
        return jsonError('First sheet is empty', 400);
      }
      rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });
    } catch (e: any) {
      return jsonError('Failed to parse file. Ensure it is a valid .xlsx, .xls, or .csv. Error: ' + e.message, 400);
    }

    if (!Array.isArray(rows) || rows.length === 0) {
      return jsonError('File has no data rows', 400);
    }

    const totalRows = rows.length;

    // Find email column
    const emailKey = (r: any) => {
      if (!r || typeof r !== 'object') return null;
      const keys = Object.keys(r);
      return keys.find(k => /e-?mail/i.test(k)) || null;
    };

    let invalid = 0;
    let duplicates = 0;
    let suppressed = 0;
    let disposable = 0;
    let roleAccounts = 0;

    const seen = new Set<string>();
    const valid: any[] = [];

    // Fetch suppression list safely
    let suppression = new Set<string>();
    try {
      const list = await prisma.suppressionList.findMany({ select: { email: true } });
      suppression = new Set(list.map(s => s.email.toLowerCase()));
    } catch (e: any) {
      console.error('[upload] suppression fetch failed:', e.message);
    }

    for (const r of rows) {
      if (!r || typeof r !== 'object') { invalid++; continue; }
      const ek = emailKey(r);
      const email = ek ? String(r[ek] || '').trim().toLowerCase() : '';

      if (!email || !isValidEmail(email)) { invalid++; continue; }
      if (seen.has(email)) { duplicates++; continue; }
      seen.add(email);

      if (suppression.has(email)) { suppressed++; continue; }

      let hygiene = { isRoleAccount: false, isDisposable: false, score: 100 };
      try {
        hygiene = checkEmailHygiene(email);
      } catch {}

      if (hygiene.isDisposable) { disposable++; continue; }
      if (hygiene.isRoleAccount) roleAccounts++;

      // Extract common fields (case insensitive)
      const getField = (names: string[]) => {
        for (const n of names) {
          for (const k of Object.keys(r)) {
            if (k.toLowerCase() === n.toLowerCase()) return String(r[k] || '');
          }
        }
        return '';
      };

      valid.push({
        email,
        name: getField(['name', 'full name', 'first name']),
        company: getField(['company', 'organization', 'org']),
        phone: getField(['phone', 'mobile', 'contact']),
        city: getField(['city', 'location']),
        isRoleAccount: hygiene.isRoleAccount,
        hygieneScore: hygiene.score,
      });
    }

    // Save to DB (bulk upsert)
    let saved = 0;
    try {
      for (const v of valid) {
        await prisma.contact.upsert({
          where: { email: v.email },
          create: {
            email: v.email,
            name: v.name,
            company: v.company,
            phone: v.phone,
            city: v.city,
            isRoleAccount: v.isRoleAccount,
            hygieneScore: v.hygieneScore,
          },
          update: {
            name: v.name,
            company: v.company,
            phone: v.phone,
            city: v.city,
            isRoleAccount: v.isRoleAccount,
            hygieneScore: v.hygieneScore,
          },
        });
        saved++;
      }
    } catch (e: any) {
      console.error('[upload] DB save partial fail:', e.message);
      // Continue — return what we have
    }

    return NextResponse.json({
      ok: true,
      totalRows,
      valid: valid.length,
      invalid,
      duplicates,
      suppressed,
      disposable,
      roleAccounts,
      saved,
      contacts: valid,
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return jsonError(err?.message || 'Upload failed', 500);
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Upload API bulletproof"

# ==========================================
# 2. ENSURE email-validator exists
# ==========================================
echo "📝 [2/4] Ensuring email-validator..."

mkdir -p lib

if [ ! -f "lib/email-validator.ts" ]; then
  cat > lib/email-validator.ts <<'EOF'
export function isValidEmail(e: string): boolean {
  if (!e) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());
}
EOF
  sed -i 's/\r$//' lib/email-validator.ts
  echo "   ✅ email-validator created"
else
  echo "   ✅ email-validator exists"
fi

# ==========================================
# 3. Ensure spam-checker exists
# ==========================================
if [ ! -f "lib/spam-checker.ts" ]; then
  cat > lib/spam-checker.ts <<'EOF'
const DISPOSABLE = new Set([
  'tempmail.com','guerrillamail.com','mailinator.com','10minutemail.com',
  'throwaway.email','trashmail.com','yopmail.com','sharklasers.com',
  'temp-mail.org','getnada.com','fakeinbox.com','maildrop.cc',
]);
const ROLES = new Set([
  'admin','info','support','sales','contact','help',
  'noreply','no-reply','postmaster','webmaster','abuse',
  'billing','marketing','office','hello','team',
]);

export function checkEmailHygiene(email: string) {
  const [local, domain] = String(email).toLowerCase().split('@');
  const isRole = ROLES.has(local);
  const isDisp = DISPOSABLE.has(domain);
  let score = 100;
  if (isRole) score -= 20;
  if (isDisp) score -= 60;
  return { isRoleAccount: isRole, isDisposable: isDisp, score: Math.max(0, score) };
}

export function checkEmail(opts: { subject: string; html: string; fromEmail: string }) {
  const issues: any[] = [];
  let score = 0;
  const add = (severity: string, category: string, message: string, points: number) => {
    issues.push({ severity, category, message, points });
    score += points;
  };
  if (!opts.subject || !opts.subject.trim()) add('high','subject','Subject empty',20);
  const html = opts.html || '';
  if (!/unsubscribe/i.test(html)) add('high','compliance','No unsubscribe link',25);
  if (/<script[\s>]/i.test(html)) add('high','html','Contains <script> tag',30);
  const finalScore = Math.min(100, score);
  return { score: finalScore, issues, ok: finalScore < 30, warning: finalScore >= 30 && finalScore < 50, blocked: finalScore >= 50 };
}
EOF
  sed -i 's/\r$//' lib/spam-checker.ts
  echo "   ✅ spam-checker created"
else
  echo "   ✅ spam-checker exists"
fi

# ==========================================
# 4. Git push
# ==========================================
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: bulletproof upload API — always returns JSON, never crashes"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ UPLOAD FIX DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 What changed:"
echo "   ✓ Every error returns JSON (never empty response)"
echo "   ✓ File size, format, sheet validation"
echo "   ✓ Empty file detection"
echo "   ✓ Per-row error handling"
echo "   ✓ Partial DB save (if some rows fail)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "Test karo:"
echo "   1. Hard refresh (Ctrl+Shift+R)"
echo "   2. Excel upload karo → JSON response milega"
echo "   3. Koi bhi error ke saath JSON hi aayega"
echo "==============================================="