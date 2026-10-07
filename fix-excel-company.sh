#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🏢 FIX: Excel Company Column Detection"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. REWRITE UPLOAD API — smart column detection
# ═══════════════════════════════════════════
echo "📝 [1/4] Rewriting upload API with smart detection..."

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
  return NextResponse.json(
    { success: false, error, details: details || null },
    { status }
  );
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function cleanEmail(v: any): string {
  if (v === null || v === undefined) return '';
  return String(v).trim().replace(/^["']+|["']+$/g, '').trim().toLowerCase();
}

function normalizeHeader(h: string): string {
  return String(h || '').trim().toLowerCase().replace(/[_\-\s]+/g, '');
}

// ═══════════════════════════════════════════
// FIELD NAME DETECTION
// ═══════════════════════════════════════════
const EMAIL_HEADERS = ['email', 'emailaddress', 'mail', 'emailid', 'emailaddress1', 'mailid'];
const COMPANY_HEADERS = [
  'company', 'companyname', 'organization', 'organisation', 'org',
  'business', 'businessname', 'firm', 'employer', 'workplace', 'corp',
  'corporation', 'brand', 'enterprise', 'client', 'clientname', 'customername'
];
const NAME_HEADERS = [
  'name', 'fullname', 'firstname', 'lastname', 'contactname', 'personname'
];
const PHONE_HEADERS = ['phone', 'mobile', 'contact', 'phonenumber', 'mobilenumber', 'tel'];
const CITY_HEADERS = ['city', 'location', 'town', 'place'];

function findColumn(headers: string[], candidates: string[]): string | null {
  for (const cand of candidates) {
    const cn = normalizeHeader(cand);
    for (const h of headers) {
      if (normalizeHeader(h) === cn) return h;
    }
  }
  return null;
}

function parseCSV(text: string): any[] {
  const clean = text.replace(/^\uFEFF/, '');
  const lines = clean.split(/\r?\n/).filter(l => l.trim().length > 0);
  if (lines.length < 2) return [];

  // Detect delimiter
  const first = lines[0];
  const counts: Record<string, number> = {
    ',': (first.match(/,/g) || []).length,
    ';': (first.match(/;/g) || []).length,
    '\t': (first.match(/\t/g) || []).length,
  };
  let delim = ',';
  let max = 0;
  for (const [d, n] of Object.entries(counts)) {
    if (n > max) { max = n; delim = d; }
  }

  const parseLine = (line: string): string[] => {
    const out: string[] = [];
    let cur = '';
    let inQ = false;
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
    headers.forEach((h, idx) => {
      row[h || `col${idx}`] = (vals[idx] ?? '').toString().trim();
    });
    rows.push(row);
  }
  return rows;
}

export async function POST(req: Request) {
  try {
    let form: FormData;
    try {
      form = await req.formData();
    } catch (e: any) {
      return fail('Form parse failed: ' + e.message);
    }

    const file = form.get('file') as File | null;
    if (!file) return fail('No file uploaded');

    if (file.size === 0) return fail('File is empty');
    if (file.size > 15 * 1024 * 1024) return fail('File too large (max 15MB)');

    const name = (file.name || '').toLowerCase();
    const isCSV = name.endsWith('.csv');
    const isXLS = name.endsWith('.xlsx') || name.endsWith('.xls');

    if (!isCSV && !isXLS) return fail('Unsupported file type');

    let buf: Buffer;
    try {
      buf = Buffer.from(await file.arrayBuffer());
    } catch (e: any) {
      return fail('Read failed: ' + e.message);
    }

    // Parse
    let rows: any[] = [];
    let parser = 'unknown';

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
        return fail('Excel parse failed. Save as CSV and retry.', e.message);
      }
    }

    if (!rows.length) return fail('No data rows');

    // ═══════════════════════════════════════════
    // SMART COLUMN DETECTION
    // ═══════════════════════════════════════════
    const sample = rows[0];
    const headers = Object.keys(sample || {});

    console.log('[upload] Detected headers:', headers);

    // Find email column
    let emailKey = findColumn(headers, EMAIL_HEADERS);

    // If not found, try to detect by value (contains @)
    if (!emailKey) {
      for (const h of headers) {
        const v = String(sample[h] || '');
        if (v.includes('@') && EMAIL_RE.test(v)) {
          emailKey = h;
          break;
        }
      }
    }

    if (!emailKey) {
      return fail('Email column not found', `Available: ${headers.join(', ')}`);
    }

    // Find company column
    let companyKey = findColumn(headers, COMPANY_HEADERS);

    // If not found AND there are only 2 columns, treat the other as company
    if (!companyKey) {
      const others = headers.filter(h => h !== emailKey);
      if (others.length === 1) {
        companyKey = others[0];
        console.log('[upload] Only 2 columns — other column treated as COMPANY:', companyKey);
      } else if (others.length > 0) {
        // If header contains "company" (case-insensitive), use it
        for (const h of others) {
          const lh = h.toLowerCase();
          if (/company|organi|business|firm|employer|corp/.test(lh)) {
            companyKey = h;
            break;
          }
        }
      }
    }

    // Find name column (strict — only explicit name headers)
    const nameKey = findColumn(headers, NAME_HEADERS);
    const phoneKey = findColumn(headers, PHONE_HEADERS);
    const cityKey = findColumn(headers, CITY_HEADERS);

    console.log('[upload] Column mapping:', {
      email: emailKey,
      company: companyKey,
      name: nameKey,
      phone: phoneKey,
      city: cityKey,
    });

    // ═══════════════════════════════════════════
    // PROCESS ROWS
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

      if (seen.has(email)) {
        duplicateList.push(email);
        continue;
      }
      seen.add(email);

      const company = companyKey ? String(row[companyKey] || '').trim() : '';
      const personName = nameKey ? String(row[nameKey] || '').trim() : '';
      const phone = phoneKey ? String(row[phoneKey] || '').trim() : '';
      const city = cityKey ? String(row[cityKey] || '').trim() : '';

      valid.push({
        email,
        name: personName,
        company,
        phone,
        city,
      });
    }

    console.log('[upload] Processed: valid=' + valid.length + ' invalid=' + invalid + ' dup=' + duplicateList.length);
    console.log('[upload] Sample row:', valid[0]);

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
      mapping: {
        email: emailKey,
        company: companyKey,
        name: nameKey,
      },
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return fail('Server error: ' + (err?.message || 'unknown'), err?.stack?.slice(0, 300), 500);
  }
}
EOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Upload API with smart detection"

# ═══════════════════════════════════════════
# 2. VERIFY CAMPAIGN PAGE — Company column present
# ═══════════════════════════════════════════
echo ""
echo "🎨 [2/4] Ensuring Company column in UI..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Campaign page not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Ensure Company column header
if (!c.includes('>Company</th>')) {
  c = c.replace(
    /(<th style=\{\{ textAlign: 'left', padding: 10, color: 'var\(--fg-muted\)', fontWeight: 700 \}\}>Name<\/th>)/,
    `$1
                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Company</th>`
  );
}

// Ensure Company cell
if (!c.includes("{c.company || '—'}")) {
  c = c.replace(
    /(<td style=\{\{ padding: 10, color: 'var\(--fg-muted\)' \}\}>\{c\.name \|\| '—'\}<\/td>)/,
    `$1
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}</td>`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Company column verified');
NODEEOF

# ═══════════════════════════════════════════
# 3. Update personalization — company in subject
# ═══════════════════════════════════════════
echo ""
echo "📝 [3/4] Updating subject personalization..."

cat > lib/personalization.ts <<'EOF'
/**
 * Personalization + Subject formatting
 * Priority: name → company → email prefix
 */

export function renderTemplate(template: string, data: Record<string, any>): string {
  if (!template) return '';
  return template.replace(
    /\{\{\s*(\w+)(?:\s*\|\s*default\s*:\s*"([^"]*)")?\s*\}\}/g,
    (_m, key, def) => {
      const v = data[key];
      if (v === undefined || v === null || v === '') return def ?? '';
      return String(v);
    }
  );
}

function nameFromEmail(email: string): string {
  if (!email) return 'Friend';
  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  const pretty = clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
  return pretty || 'Friend';
}

/**
 * Get best display label.
 * Priority: name → company → email prefix
 */
export function getRecipientName(data: Record<string, any>): string {
  const personName = String(data.name || '').trim();
  if (personName) return personName;

  const company = String(data.company || '').trim();
  if (company) return company;

  return nameFromEmail(String(data.email || ''));
}

/**
 * Format subject with client name (or company) + CONGRATULATIONS prefix.
 */
export function formatSubject(subjectTemplate: string, data: Record<string, any>): string {
  if (!subjectTemplate) return '';
  const name = getRecipientName(data);
  const subject = subjectTemplate.trim();

  // If has {{name}} or {{company}} variable — just render
  if (/\{\{\s*(name|company)/.test(subject)) {
    return renderTemplate(subject, { ...data, name, company: data.company || name });
  }

  // If starts with CONGRATULATIONS
  const upperSubject = subject.toUpperCase();
  if (upperSubject.startsWith('CONGRATULATIONS')) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${name} — ${rest}`
      : `CONGRATULATIONS 🎉 ${name}`;
  }

  // Prepend prefix
  return `CONGRATULATIONS 🎉 ${name} — ${subject}`;
}

export function personalize(data: Record<string, any>, subjectTemplate: string, htmlTemplate: string) {
  return {
    subject: formatSubject(subjectTemplate, data),
    html: renderTemplate(htmlTemplate, data),
  };
}
EOF
sed -i 's/\r$//' lib/personalization.ts
echo "   ✅ Personalization updated"

# ═══════════════════════════════════════════
# 4. Git push
# ═══════════════════════════════════════════
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: smart Excel detection — 2nd column = company when only 2 columns"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ SMART EXCEL DETECTION DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Kaise Kaam Karega:"
echo ""
echo "Aapki Excel (2 columns):"
echo "   | Company Name | Email            |"
echo "   |--------------|------------------|"
echo "   | Acme Corp    | rahul@company.com|"
echo ""
echo "Detection logic:"
echo "   1. Email column → detect by header OR by '@' value"
echo "   2. Other 1 column → treat as COMPANY"
echo "   3. Company detected → use in 'Company' field"
echo ""
echo "Subject me:"
echo "   'Congratulations' → 'CONGRATULATIONS 🎉 Acme Corp'"
echo "   (uses company if name empty)"
echo ""
echo "Smart rules:"
echo "   • 2 columns: email + X → X = company"
echo "   • 3+ columns: check headers for 'company', 'org', 'business'"
echo "   • Name only if header is 'name', 'fullname', 'firstname'"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📱 Test: /campaigns/new → Excel upload karo"
echo "==============================================="