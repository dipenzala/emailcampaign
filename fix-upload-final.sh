#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FINAL UPLOAD FIX — exceljs + Debug"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Add exceljs + xlsx to dependencies
# ==========================================
echo "📦 [1/5] Ensuring Excel libraries..."

node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.dependencies = pkg.dependencies || {};

// Add BOTH parsers — whichever works
pkg.dependencies.xlsx = '^0.18.5';
pkg.dependencies['exceljs'] = '^4.4.0';

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ xlsx + exceljs added to dependencies');
NODEEOF

# ==========================================
# 2. DEBUG ENDPOINT — test if APIs work
# ==========================================
echo ""
echo "🔍 [2/5] Creating debug endpoint..."

mkdir -p app/api/debug/upload-test

cat > app/api/debug/upload-test/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const results: any = {
    timestamp: new Date().toISOString(),
    checks: {},
  };

  // Check 1: Basic
  results.checks.basic = 'ok';

  // Check 2: xlsx
  try {
    const XLSX = await import('xlsx');
    results.checks.xlsx = {
      ok: true,
      version: XLSX.version || 'unknown',
      hasRead: typeof XLSX.read === 'function',
    };
  } catch (e: any) {
    results.checks.xlsx = { ok: false, error: e.message };
  }

  // Check 3: exceljs
  try {
    const ExcelJS = await import('exceljs');
    results.checks.exceljs = {
      ok: true,
      hasWorkbook: typeof ExcelJS.Workbook === 'function',
    };
  } catch (e: any) {
    results.checks.exceljs = { ok: false, error: e.message };
  }

  // Check 4: Prisma
  try {
    const { prisma } = await import('@/lib/prisma');
    const count = await prisma.contact.count();
    results.checks.prisma = { ok: true, contacts: count };
  } catch (e: any) {
    results.checks.prisma = { ok: false, error: e.message };
  }

  return NextResponse.json({ ok: true, ...results });
}
EOF
sed -i 's/\r$//' app/api/debug/upload-test/route.ts
echo "   ✅ /api/debug/upload-test"

# ==========================================
# 3. REWRITE UPLOAD API — ExcelJS primary, XLSX fallback
# ==========================================
echo ""
echo "📝 [3/5] Rewriting upload API..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

function validEmail(e: string): boolean {
  return !!e && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());
}

const DISPOSABLE = new Set([
  'tempmail.com','guerrillamail.com','mailinator.com','10minutemail.com',
  'throwaway.email','trashmail.com','yopmail.com','sharklasers.com',
  'temp-mail.org','getnada.com','fakeinbox.com','maildrop.cc',
]);

const ROLES = new Set([
  'admin','info','support','sales','contact','help','noreply','no-reply',
  'postmaster','webmaster','abuse','billing','marketing','office','hello','team',
]);

export async function POST(req: Request) {
  console.log('[upload] START');

  try {
    let form: FormData;
    try {
      form = await req.formData();
    } catch (e: any) {
      return j({ ok: false, error: 'Form parse failed: ' + e.message }, 400);
    }

    const file = form.get('file');
    if (!file || typeof file === 'string') {
      return j({ ok: false, error: 'No file uploaded' }, 400);
    }

    const f = file as File;
    console.log('[upload] file:', f.name, 'size:', f.size, 'type:', f.type);

    if (f.size === 0) return j({ ok: false, error: 'File empty' }, 400);
    if (f.size > 10 * 1024 * 1024) return j({ ok: false, error: 'File > 10MB' }, 400);

    let buf: Buffer;
    try {
      buf = Buffer.from(await f.arrayBuffer());
    } catch (e: any) {
      return j({ ok: false, error: 'Read failed: ' + e.message }, 400);
    }

    // Determine file type
    const lowerName = (f.name || '').toLowerCase();
    const isCSV = lowerName.endsWith('.csv');
    const isXLSX = lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls');

    let rows: any[] = [];
    let parser = 'unknown';

    // CSV — pure manual parse (no dependency)
    if (isCSV) {
      try {
        const text = buf.toString('utf-8').replace(/^\uFEFF/, '');
        const lines = text.split(/\r?\n/).filter(l => l.trim());
        if (lines.length < 2) return j({ ok: false, error: 'CSV has no data rows' }, 400);

        // Parse header
        const parseCSVLine = (line: string): string[] => {
          const out: string[] = [];
          let cur = '';
          let inQuote = false;
          for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (inQuote) {
              if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
              else if (ch === '"') { inQuote = false; }
              else cur += ch;
            } else {
              if (ch === '"') inQuote = true;
              else if (ch === ',') { out.push(cur.trim()); cur = ''; }
              else cur += ch;
            }
          }
          out.push(cur.trim());
          return out;
        };

        const headers = parseCSVLine(lines[0]);
        for (let i = 1; i < lines.length; i++) {
          const vals = parseCSVLine(lines[i]);
          const row: any = {};
          headers.forEach((h, idx) => { row[h] = vals[idx] || ''; });
          rows.push(row);
        }
        parser = 'csv-native';
      } catch (e: any) {
        return j({ ok: false, error: 'CSV parse failed: ' + e.message }, 400);
      }
    }

    // XLSX — try ExcelJS first, then xlsx
    if (isXLSX) {
      let parsed = false;

      // Try 1: ExcelJS
      try {
        const ExcelJS = await import('exceljs');
        const wb = new ExcelJS.Workbook();
        await wb.xlsx.load(buf as any);
        const sheet = wb.worksheets[0];
        if (sheet) {
          const headerRow = sheet.getRow(1);
          const headers: string[] = [];
          headerRow.eachCell((cell: any, col: number) => {
            headers[col - 1] = String(cell.value ?? '').trim();
          });
          sheet.eachRow((row: any, rowNumber: number) => {
            if (rowNumber === 1) return;
            const r: any = {};
            row.eachCell((cell: any, col: number) => {
              const h = headers[col - 1] || `col${col}`;
              let v = cell.value;
              if (v && typeof v === 'object' && 'text' in v) v = v.text;
              else if (v && typeof v === 'object' && 'result' in v) v = v.result;
              r[h] = v ?? '';
            });
            rows.push(r);
          });
          parser = 'exceljs';
          parsed = true;
          console.log('[upload] exceljs parsed rows:', rows.length);
        }
      } catch (e: any) {
        console.warn('[upload] exceljs failed:', e.message);
      }

      // Try 2: xlsx (fallback)
      if (!parsed) {
        try {
          const XLSX = await import('xlsx');
          const wb = XLSX.read(buf, { type: 'buffer' });
          const sheet = wb.Sheets[wb.SheetNames[0]];
          rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });
          parser = 'xlsx';
          parsed = true;
          console.log('[upload] xlsx parsed rows:', rows.length);
        } catch (e: any) {
          console.warn('[upload] xlsx failed:', e.message);
          return j({
            ok: false,
            error: 'Excel parser unavailable. Please save your file as CSV and upload again.',
            details: e.message,
          }, 400);
        }
      }
    }

    if (!rows.length) {
      return j({ ok: false, error: 'No data rows found. Save as CSV and retry.' }, 400);
    }

    const totalRows = rows.length;

    // Find email column
    const findEmailKey = (r: any): string | null => {
      if (!r || typeof r !== 'object') return null;
      const keys = Object.keys(r);
      return keys.find(k => /e-?mail/i.test(k)) || keys[0] || null;
    };

    // Process
    const seen = new Set<string>();
    const valid: any[] = [];
    const duplicateList: string[] = [];
    const invalidList: { email: string; reason: string }[] = [];
    let invalid = 0, disposable = 0, roleAccounts = 0;

    // Safe suppression
    let suppressionSet = new Set<string>();
    try {
      const { prisma } = await import('@/lib/prisma');
      const list = await prisma.suppressionList.findMany({ select: { email: true } });
      suppressionSet = new Set(list.map((s: any) => s.email.toLowerCase()));
    } catch (e: any) {
      console.warn('[upload] suppression fetch failed:', e.message);
    }

    for (const r of rows) {
      if (!r || typeof r !== 'object') { invalid++; continue; }
      const ek = findEmailKey(r);
      const rawEmail = ek ? String(r[ek] || '').trim().toLowerCase() : '';

      if (!rawEmail) { invalid++; continue; }
      if (!validEmail(rawEmail)) {
        invalid++;
        invalidList.push({ email: rawEmail, reason: 'Invalid format' });
        continue;
      }
      if (seen.has(rawEmail)) {
        duplicateList.push(rawEmail);
        continue;
      }
      seen.add(rawEmail);

      if (suppressionSet.has(rawEmail)) {
        invalidList.push({ email: rawEmail, reason: 'Suppressed' });
        continue;
      }

      const [local, domain] = rawEmail.split('@');
      if (DISPOSABLE.has(domain)) {
        disposable++;
        invalidList.push({ email: rawEmail, reason: 'Disposable' });
        continue;
      }
      const isRole = ROLES.has(local);
      if (isRole) roleAccounts++;

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
        isRoleAccount: isRole,
      });
    }

    // Save
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
          console.warn('[upload] save fail', v.email, e.message);
        }
      }
    } catch (e: any) {
      console.warn('[upload] DB failed:', e.message);
    }

    console.log('[upload] DONE parser=%s valid=%d invalid=%d dup=%d', parser, valid.length, invalid, duplicateList.length);

    return j({
      ok: true,
      parser,
      totalRows,
      valid: valid.length,
      invalid,
      duplicates: duplicateList.length,
      duplicateList: duplicateList.slice(0, 100),
      disposable,
      roleAccounts,
      saved,
      invalidList: invalidList.slice(0, 100),
      contacts: valid,
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return j({ ok: false, error: err?.message || 'Server error' }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Upload API rewritten"

# ==========================================
# 4. UPDATE FRONTEND — better error handling
# ==========================================
echo ""
echo "📝 [4/5] Improving frontend error handling..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) { console.log('   ⚠️  page not found'); process.exit(0); }

let c = fs.readFileSync(f, 'utf8');

// Improve uploadFile error handling
if (!c.includes('const responseText')) {
  c = c.replace(
    /const r = await fetch\('\/api\/contacts\/upload', \{ method: 'POST', body: fd \}\);\s*const j = await r\.json\(\);\s*if \(!r\.ok\) \{\s*throw new Error\(j\.error \|\| 'Upload failed'\);\s*\}/,
    `const r = await fetch('/api/contacts/upload', { method: 'POST', body: fd });
      const responseText = await r.text();
      let j: any;
      try {
        j = JSON.parse(responseText);
      } catch (parseErr) {
        // Server sent HTML error page
        console.error('Non-JSON response:', responseText.slice(0, 200));
        throw new Error('Server error. Check Vercel logs. (Preview: ' + responseText.slice(0, 100) + ')');
      }
      if (!r.ok) {
        throw new Error(j.error || 'Upload failed');
      }`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Frontend handles non-JSON responses');
NODEEOF

# ==========================================
# 5. Git push
# ==========================================
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: exceljs primary parser + CSV native + debug endpoint + better errors"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 3 parsers now:"
echo "   1. ExcelJS (primary)"
echo "   2. xlsx (fallback)"
echo "   3. Native CSV parser (no deps)"
echo ""
echo "📊 Test endpoints:"
echo "   1. Debug check:"
echo "      https://emailcampaign-ten.vercel.app/api/debug/upload-test"
echo "   2. Then try upload again"
echo ""
echo "⚠️  IMPORTANT — CSV Workaround"
echo "   Excel me file kholo → Save As → CSV → phir upload karo"
echo "   CSV always works (no dependency needed)"
echo ""
echo "📋 Vercel Build Logs check karo:"
echo "   https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo "   Latest → Build Logs → search 'xlsx' or 'exceljs'"
echo "==============================================="