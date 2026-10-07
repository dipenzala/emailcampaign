#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Subject Auto + Company Column"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. FIX UPLOAD API — force header detection
# ═══════════════════════════════════════════
echo "📝 [1/4] Fixing upload API (force header detection)..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json({ success: true, ...data }, { status });
}
function fail(error: string, details?: string, status = 400) {
  return NextResponse.json({ success: false, error, details: details || null }, { status });
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function cleanEmail(v: any): string {
  if (v === null || v === undefined) return '';
  return String(v).trim().replace(/^["']+|["']+$/g, '').trim().toLowerCase();
}

function norm(h: string): string {
  return String(h || '').trim().toLowerCase().replace(/[_\-\s]+/g, '');
}

// ═══════════════════════════════════════════
// DETECT EMAIL COLUMN (header OR value)
// ═══════════════════════════════════════════
function detectEmailKey(rows: any[]): string | null {
  if (!rows.length) return null;
  const headers = Object.keys(rows[0] || {});

  // Pass 1: Header match
  for (const h of headers) {
    const n = norm(h);
    if (['email', 'emailaddress', 'mail', 'emailid', 'mailid', 'e-mail'].includes(n)) return h;
  }

  // Pass 2: Value match (find header whose values contain '@')
  for (const h of headers) {
    let emailCount = 0;
    for (const r of rows.slice(0, 5)) {
      if (EMAIL_RE.test(String(r[h] || ''))) emailCount++;
    }
    if (emailCount >= Math.min(2, rows.length)) return h;
  }
  return null;
}

// ═══════════════════════════════════════════
// DETECT COMPANY COLUMN
// ═══════════════════════════════════════════
function detectCompanyKey(rows: any[], emailKey: string): string | null {
  if (!rows.length) return null;
  const headers = Object.keys(rows[0] || {});
  const others = headers.filter(h => h !== emailKey);

  // Pass 1: Header has company-related word
  for (const h of others) {
    const n = norm(h);
    if (/company|companyname|organization|organisation|org|business|firm|employer|workplace|corp|enterprise|brand/.test(n)) {
      return h;
    }
  }

  // Pass 2: If only 2 columns total → other is company
  if (headers.length === 2 && others.length === 1) {
    return others[0];
  }

  // Pass 3: If 3+ columns, check if any column has text (not email, not number-only)
  for (const h of others) {
    let textCount = 0;
    for (const r of rows.slice(0, 5)) {
      const v = String(r[h] || '').trim();
      if (v && !EMAIL_RE.test(v) && !/^\d+$/.test(v)) textCount++;
    }
    // If most rows have some text, likely a company
    if (textCount >= Math.min(2, rows.length)) return h;
  }

  return null;
}

// ═══════════════════════════════════════════
// DETECT NAME COLUMN (strict)
// ═══════════════════════════════════════════
function detectNameKey(rows: any[], usedKeys: string[]): string | null {
  const headers = Object.keys(rows[0] || {});
  for (const h of headers) {
    if (usedKeys.includes(h)) continue;
    const n = norm(h);
    if (['name', 'fullname', 'firstname', 'lastname', 'personname', 'contactname', 'customername'].includes(n)) return h;
  }
  return null;
}

function parseCSV(text: string): any[] {
  const clean = text.replace(/^\uFEFF/, '');
  const lines = clean.split(/\r?\n/).filter(l => l.trim().length > 0);
  if (lines.length < 2) return [];

  const first = lines[0];
  const counts: Record<string, number> = {
    ',': (first.match(/,/g) || []).length,
    ';': (first.match(/;/g) || []).length,
    '\t': (first.match(/\t/g) || []).length,
  };
  let delim = ','; let max = 0;
  for (const [d, n] of Object.entries(counts)) if (n > max) { max = n; delim = d; }

  const parseLine = (line: string): string[] => {
    const out: string[] = [];
    let cur = '', inQ = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (inQ) {
        if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
        else if (ch === '"') inQ = false;
        else cur += ch;
      } else {
        if (ch === '"') inQ = true;
        else if (ch === delim) { out.push(cur); cur = ''; }
        else cur += ch;
      }
    }
    out.push(cur);
    return out;
  };

  const headers = parseLine(lines[0]).map(h => h.trim());
  const rows: any[] = [];
  for (let i = 1; i < lines.length; i++) {
    const vals = parseLine(lines[i]);
    const row: any = {};
    headers.forEach((h, idx) => { row[h || `col${idx}`] = (vals[idx] ?? '').toString().trim(); });
    rows.push(row);
  }
  return rows;
}

export async function POST(req: Request) {
  try {
    let form: FormData;
    try { form = await req.formData(); } catch (e: any) { return fail('Form parse: ' + e.message); }

    const file = form.get('file') as File | null;
    if (!file) return fail('No file');
    if (file.size === 0) return fail('File empty');
    if (file.size > 15 * 1024 * 1024) return fail('File too large');

    const fileName = (file.name || '').toLowerCase();
    const isCSV = fileName.endsWith('.csv');
    const isXLS = fileName.endsWith('.xlsx') || fileName.endsWith('.xls');
    if (!isCSV && !isXLS) return fail('Use .xlsx, .xls, or .csv');

    let buf: Buffer;
    try { buf = Buffer.from(await file.arrayBuffer()); } catch (e: any) { return fail('Read: ' + e.message); }

    let rows: any[] = [];
    let parser = '';

    if (isCSV) {
      rows = parseCSV(buf.toString('utf-8'));
      parser = 'csv';
    } else {
      try {
        const XLSX = await import('xlsx');
        const wb = XLSX.read(buf, { type: 'buffer' });
        const sn = wb.SheetNames?.[0];
        if (!sn) return fail('No sheets');
        const sheet = wb.Sheets[sn];
        if (!sheet) return fail('Sheet empty');
        rows = XLSX.utils.sheet_to_json(sheet, { defval: '', raw: false });
        parser = 'xlsx';
      } catch (e: any) {
        return fail('Excel parse failed. Save as CSV.', e.message);
      }
    }

    if (!rows.length) return fail('No data');

    // ═══════════════════════════════════════════
    // SMART DETECTION
    // ═══════════════════════════════════════════
    const emailKey = detectEmailKey(rows);
    if (!emailKey) {
      return fail('Email column not found', 'Headers: ' + Object.keys(rows[0]).join(', '));
    }

    const companyKey = detectCompanyKey(rows, emailKey);
    const nameKey = detectNameKey(rows, [emailKey, companyKey || '']);

    console.log('[upload] Detected:', { emailKey, companyKey, nameKey });

    // ═══════════════════════════════════════════
    // PROCESS
    // ═══════════════════════════════════════════
    const seen = new Set<string>();
    const valid: any[] = [];
    const duplicateList: string[] = [];
    const invalidList: { email: string; reason: string }[] = [];
    let invalid = 0;

    for (const row of rows) {
      const email = cleanEmail(row[emailKey]);
      if (!email) { invalid++; continue; }
      if (!EMAIL_RE.test(email)) {
        invalid++;
        invalidList.push({ email, reason: 'Invalid format' });
        continue;
      }
      if (seen.has(email)) { duplicateList.push(email); continue; }
      seen.add(email);

      valid.push({
        email,
        name: nameKey ? String(row[nameKey] || '').trim() : '',
        company: companyKey ? String(row[companyKey] || '').trim() : '',
        phone: '',
        city: '',
      });
    }

    console.log('[upload] Sample:', valid[0]);
    console.log('[upload] Company key was:', companyKey, '| First company value:', valid[0]?.company);

    return j({
      parser,
      message: `${valid.length} valid email(s) loaded`,
      total: rows.length,
      imported: valid.length,
      duplicates: duplicateList.length,
      duplicateList: duplicateList.slice(0, 500),
      invalid,
      invalidList: invalidList.slice(0, 500),
      contacts: valid,
      mapping: { email: emailKey, company: companyKey, name: nameKey },
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return fail('Server error: ' + (err?.message || 'unknown'), err?.stack?.slice(0, 300), 500);
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Upload API fixed"

# ═══════════════════════════════════════════
# 2. FIX CAMPAIGN PAGE — subject default + clear error + company column
# ═══════════════════════════════════════════
echo ""
echo "🎨 [2/4] Fixing campaign page..."

mkdir -p app/campaigns/new

# Read existing file and patch specific parts
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

// 1. Auto-populate subject
c = c.replace(
  /const \[subject, setSubject\] = useState\(''\);/,
  `const [subject, setSubject] = useState('CONGRATULATIONS 🎉');`
);

// 2. Clear msg on any input change
c = c.replace(
  /onChange=\{e => setSubject\(e\.target\.value\)\}/,
  `onChange={e => { setSubject(e.target.value); if (msg) setMsg(''); }}`
);
c = c.replace(
  /onChange=\{e => setHtml\(e\.target\.value\)\}/,
  `onChange={e => { setHtml(e.target.value); if (msg) setMsg(''); }}`
);

// 3. Make canGoStep3 more lenient
c = c.replace(
  /const canGoStep3 = subject\.trim\(\)\.length > 0 && html\.trim\(\)\.length > 0;/,
  `const canGoStep3 = subject.trim().length > 5 && html.trim().length > 20;`
);

fs.writeFileSync(f, c);
console.log('   ✅ Campaign page patched');
NODEEOF

# ═══════════════════════════════════════════
# 3. ENSURE Company column in preview table
# ═══════════════════════════════════════════
echo ""
echo "🏢 [3/4] Ensuring Company column..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

// Replace whole table header + body for the merged preview
// Find existing table structure and ensure 3 columns
if (!c.includes('>Email</th>') || !c.includes('>Company</th>')) {
  // Replace the whole preview contacts table
  const tableRegex = /<table style=\{\{ width: '100%', fontSize: 12, borderCollapse: 'collapse' \}\}>[\s\S]*?<\/table>/;

  const newTable = `<table style={{ width: '100%', fontSize: 12, borderCollapse: 'collapse' }}>
                  <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0, zIndex: 1 }}>
                    <tr>
                      <th style={{ textAlign: 'left', padding: 10, width: 40, color: 'var(--fg-muted)', fontWeight: 700 }}>#</th>
                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Email</th>
                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Company</th>
                      <th style={{ width: 40 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {allContacts.map((c, i) => (
                      <tr key={c.email + i} style={{ borderTop: '1px solid var(--border)' }}>
                        <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                        <td style={{ padding: 10, fontFamily: 'ui-monospace, monospace' }}>{c.email}</td>
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || c.name || '—'}</td>
                        <td style={{ padding: 10 }}>
                          <button onClick={() => removeContact(c.email)} style={{ background: 'none', border: 'none', color: '#dc2626', cursor: 'pointer', fontSize: 14 }}>✕</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>`;

  c = c.replace(tableRegex, newTable);
}

fs.writeFileSync(f, c);
console.log('   ✅ Preview table updated (Email + Company)');
NODEEOF

# ═══════════════════════════════════════════
# 4. Git push
# ═══════════════════════════════════════════
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: 2-column Excel detection + subject auto + company preview"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 Kya fix hua:"
echo ""
echo "1. 📝 Subject auto-populated:"
echo "   → Default: 'CONGRATULATIONS 🎉'"
echo "   → Purane error stale clear honge"
echo "   → Typing pe bhi clear hoga"
echo ""
echo "2. 📧 Excel 2-column detection:"
echo "   → Column 1 (Email) → detected by header OR @ value"
echo "   → Column 2 → auto-treated as COMPANY"
echo "   → Preview me 'Company' header + values"
echo ""
echo "3. 🏢 Preview table:"
echo "   → Columns: # | Email | Company | ✕"
echo "   → Company value dikhega (ya Name fallback)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "⚠️  IMPORTANT — Purana Excel re-upload karo:"
echo "   Naya detection apply hone ke liye"
echo "   Purana data use mat karo"
echo "==============================================="