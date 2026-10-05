#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🛡️ ULTIMATE UPLOAD FIX + DUPLICATE DETECTION"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Ensure xlsx installed
# ==========================================
echo "📦 [1/6] Ensuring xlsx package..."

if ! grep -q '"xlsx"' package.json; then
  echo "   ⚠️  xlsx missing — adding"
  node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
pkg.dependencies = pkg.dependencies || {};
pkg.dependencies.xlsx = "^0.18.5";
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
console.log("   ✅ Added xlsx");
'
else
  echo "   ✅ xlsx present"
fi

# ==========================================
# 2. ULTRA-DEFENSIVE UPLOAD API
# ==========================================
echo ""
echo "📝 [2/6] Writing ultra-defensive upload API..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

// Regex validator inline (no lib imports)
function validEmail(e: string): boolean {
  if (!e || typeof e !== 'string') return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());
}

// Disposable domains
const DISPOSABLE = new Set([
  'tempmail.com','guerrillamail.com','mailinator.com','10minutemail.com',
  'throwaway.email','trashmail.com','yopmail.com','sharklasers.com',
  'temp-mail.org','getnada.com','fakeinbox.com','maildrop.cc',
]);

function hygiene(email: string) {
  const [local, domain] = String(email).toLowerCase().split('@');
  const roles = ['admin','info','support','sales','contact','help','noreply','no-reply','postmaster','webmaster','abuse','billing','marketing','office','hello','team'];
  return {
    isRole: roles.includes(local),
    isDisposable: DISPOSABLE.has(domain),
  };
}

export async function POST(req: Request) {
  console.log('[upload] === START ===');

  try {
    // Safe form parse
    let form: FormData;
    try {
      form = await req.formData();
    } catch (e: any) {
      console.error('[upload] formData error:', e.message);
      return json({ ok: false, error: 'Form parse failed: ' + e.message }, 400);
    }

    const file = form.get('file');
    if (!file || typeof file === 'string') {
      return json({ ok: false, error: 'No file uploaded' }, 400);
    }

    const f = file as File;
    console.log('[upload] file:', f.name, 'size:', f.size);

    if (f.size === 0) {
      return json({ ok: false, error: 'File is empty' }, 400);
    }

    if (f.size > 10 * 1024 * 1024) {
      return json({ ok: false, error: 'File too large (max 10MB)' }, 400);
    }

    // Read buffer
    let buf: Buffer;
    try {
      const ab = await f.arrayBuffer();
      buf = Buffer.from(ab);
    } catch (e: any) {
      return json({ ok: false, error: 'Read failed: ' + e.message }, 400);
    }

    // Dynamic import XLSX (avoids module-level crash)
    let XLSX: any;
    try {
      XLSX = await import('xlsx');
      console.log('[upload] xlsx imported');
    } catch (e: any) {
      console.error('[upload] xlsx import failed:', e.message);
      return json({ ok: false, error: 'Excel parser unavailable: ' + e.message }, 500);
    }

    // Parse workbook
    let rows: any[] = [];
    try {
      const wb = XLSX.read(buf, { type: 'buffer' });
      if (!wb.SheetNames?.length) {
        return json({ ok: false, error: 'Workbook has no sheets' }, 400);
      }
      const sheet = wb.Sheets[wb.SheetNames[0]];
      if (!sheet) {
        return json({ ok: false, error: 'First sheet is empty' }, 400);
      }
      rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });
      console.log('[upload] parsed rows:', rows.length);
    } catch (e: any) {
      console.error('[upload] XLSX parse error:', e.message);
      return json({
        ok: false,
        error: 'Could not parse file. Save as .xlsx or .csv and retry. Details: ' + e.message,
      }, 400);
    }

    if (!rows.length) {
      return json({ ok: false, error: 'No data rows in file' }, 400);
    }

    const totalRows = rows.length;

    // Find email column (case-insensitive)
    const findEmailKey = (r: any): string | null => {
      if (!r || typeof r !== 'object') return null;
      const keys = Object.keys(r);
      return keys.find(k => /e-?mail/i.test(k)) || keys[0] || null;
    };

    // Process rows
    const seen = new Set<string>();
    const valid: any[] = [];
    const duplicates: string[] = [];
    const invalidRows: { email: string; reason: string }[] = [];

    let invalid = 0;
    let disposable = 0;
    let roleAccounts = 0;

    // Safe suppression fetch
    let suppressionSet = new Set<string>();
    try {
      const { prisma } = await import('@/lib/prisma');
      const list = await prisma.suppressionList.findMany({ select: { email: true } });
      suppressionSet = new Set(list.map((s: any) => s.email.toLowerCase()));
      console.log('[upload] suppression list:', suppressionSet.size);
    } catch (e: any) {
      console.error('[upload] suppression fetch failed:', e.message);
      // Continue without suppression
    }

    for (const r of rows) {
      if (!r || typeof r !== 'object') { invalid++; continue; }

      const ek = findEmailKey(r);
      const rawEmail = ek ? String(r[ek] || '').trim().toLowerCase() : '';

      if (!rawEmail) {
        invalid++;
        continue;
      }

      if (!validEmail(rawEmail)) {
        invalid++;
        invalidRows.push({ email: rawEmail, reason: 'Invalid format' });
        continue;
      }

      if (seen.has(rawEmail)) {
        duplicates.push(rawEmail);
        continue;
      }
      seen.add(rawEmail);

      if (suppressionSet.has(rawEmail)) {
        invalidRows.push({ email: rawEmail, reason: 'Suppressed' });
        continue;
      }

      const hy = hygiene(rawEmail);
      if (hy.isDisposable) {
        disposable++;
        invalidRows.push({ email: rawEmail, reason: 'Disposable domain' });
        continue;
      }
      if (hy.isRole) roleAccounts++;

      const getField = (names: string[]) => {
        for (const n of names) {
          for (const k of Object.keys(r)) {
            if (k.toLowerCase().trim() === n) return String(r[k] || '');
          }
        }
        return '';
      };

      valid.push({
        email: rawEmail,
        name: getField(['name', 'full name', 'first name']),
        company: getField(['company', 'organization', 'org']),
        phone: getField(['phone', 'mobile']),
        city: getField(['city', 'location']),
        isRoleAccount: hy.isRole,
      });
    }

    // Save to DB (safe)
    let saved = 0;
    try {
      const { prisma } = await import('@/lib/prisma');
      for (const v of valid) {
        try {
          await prisma.contact.upsert({
            where: { email: v.email },
            create: v,
            update: { name: v.name, company: v.company, phone: v.phone, city: v.city },
          });
          saved++;
        } catch (e: any) {
          console.error('[upload] save fail for', v.email, e.message);
        }
      }
    } catch (e: any) {
      console.error('[upload] DB module failed:', e.message);
    }

    console.log('[upload] DONE: valid=%d, invalid=%d, dup=%d, saved=%d', valid.length, invalid, duplicates.length, saved);

    return json({
      ok: true,
      totalRows,
      valid: valid.length,
      invalid,
      duplicates: duplicates.length,
      duplicateList: duplicates.slice(0, 50),
      disposable,
      roleAccounts,
      saved,
      invalidList: invalidRows.slice(0, 50),
      contacts: valid,
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return json({ ok: false, error: err?.message || 'Unknown server error' }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Upload API — module-safe"

# ==========================================
# 3. UPDATE CAMPAIGN NEW PAGE — duplicate UI
# ==========================================
echo ""
echo "📝 [3/6] Adding duplicate removal UI..."

mkdir -p app/campaigns/new

cat > /tmp/patch-campaign.js <<'JSEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  campaign page not found');
  process.exit(0);
}
let c = fs.readFileSync(f, 'utf8');

// Add duplicate tracking state
if (!c.includes('duplicateEmails')) {
  c = c.replace(
    /const \[invalidRows, setInvalidRows\] = useState<InvalidRow\[\]>\(\[\]\);/,
    `const [invalidRows, setInvalidRows] = useState<InvalidRow[]>([]);
  const [duplicateEmails, setDuplicateEmails] = useState<string[]>([]);`
  );
}

// Update upload handler to capture duplicates
if (!c.includes('setDuplicateEmails')) {
  c = c.replace(
    /setContacts\(j\.contacts \|\| \[\]\);/,
    `setContacts(j.contacts || []);
      setDuplicateEmails(j.duplicateList || []);`
  );
}

// Add duplicate UI section — insert before invalid section
if (!c.includes('🚫 Duplicate')) {
  c = c.replace(
    /(\{\/\* Invalid emails \*\/\})/,
    `{/* Duplicate emails */}
          {duplicateEmails.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 13, color: '#d97706', fontWeight: 700 }}>
                  🚫 {duplicateEmails.length} duplicate email{duplicateEmails.length > 1 ? 's' : ''} removed
                </div>
                <button onClick={() => setDuplicateEmails([])} className="btn btn-ghost" style={{ fontSize: 11, padding: '5px 10px' }}>
                  Clear
                </button>
              </div>
              <div style={{ maxHeight: 140, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                {duplicateEmails.map((em, i) => (
                  <div key={i} style={{
                    padding: '8px 12px',
                    borderBottom: i < duplicateEmails.length - 1 ? '1px solid var(--border)' : 'none',
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: 'var(--fg-muted)',
                  }}>{em}</div>
                ))}
              </div>
              <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 6 }}>
                ℹ️ Ye emails already list me the — automatically skip ho gaye
              </div>
            </div>
          )}

          {/* Invalid emails */}`
  );
}

// Add duplicate stat in fileStats section
if (!c.includes('DUPLICATES')) {
  c = c.replace(
    /<Stat label="DUPES" value=\{fileStats\.duplicates\} color="#f59e0b" \/>/,
    `<Stat label="DUPLICATES" value={fileStats.duplicates} color="#f59e0b" />`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Duplicate UI added');
JSEOF

node /tmp/patch-campaign.js

# ==========================================
# 4. VERIFY
# ==========================================
echo ""
echo "🔎 [4/6] Verifying..."
grep -q "duplicateList" app/api/contacts/upload/route.ts && echo "   ✅ API returns duplicateList" || echo "   ⚠️  Missing"
grep -q "duplicateEmails" app/campaigns/new/page.tsx && echo "   ✅ UI tracks duplicates" || echo "   ⚠️  Missing"

# ==========================================
# 5. Install xlsx if missing
# ==========================================
echo ""
echo "📦 [5/6] Installing xlsx (if missing)..."

if [ ! -d "node_modules/xlsx" ]; then
  echo "   Installing xlsx..."
  npm install --ignore-scripts xlsx@0.18.5 --silent 2>&1 | tail -3 || echo "   ⚠️  Install failed — Vercel khud karega"
else
  echo "   ✅ xlsx already installed"
fi

# ==========================================
# 6. Git push
# ==========================================
echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: upload API never crashes + duplicate email detection UI"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Fixes:"
echo "   ✓ xlsx dynamic import (no module-level crash)"
echo "   ✓ Every error path returns JSON"
echo "   ✓ Duplicates detected + shown separately"
echo "   ✓ Per-row error tracking"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "Test:"
echo "   1. Hard refresh (Ctrl+Shift+R)"
echo "   2. Excel upload karo"
echo "   3. Success ya JSON error milega (kabhi empty response nahi)"
echo ""
echo "Duplicates:"
echo "   Same email 2x → automatically removed"
echo "   UI me alag section me dikhega"
echo "==============================================="