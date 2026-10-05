import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

// ═══════════════════════════════════════════
// ALWAYS return JSON — never HTML/plain text
// ═══════════════════════════════════════════
function ok(data: any) {
  return NextResponse.json({ success: true, ...data }, { status: 200 });
}
function fail(error: string, details?: string, status = 400) {
  return NextResponse.json(
    { success: false, error, details: details || null },
    { status }
  );
}

// ═══════════════════════════════════════════
// Email validation
// ═══════════════════════════════════════════
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function cleanEmail(v: any): string {
  if (v === null || v === undefined) return '';
  let s = String(v).trim();
  // Remove surrounding quotes
  s = s.replace(/^["']+|["']+$/g, '').trim();
  return s.toLowerCase();
}

function isValidEmail(e: string): boolean {
  return !!e && EMAIL_RE.test(e);
}

// ═══════════════════════════════════════════
// Header normalization
// ═══════════════════════════════════════════
function normalizeHeader(h: string): string {
  return String(h || '').trim().toLowerCase().replace(/[_\-\s]+/g, '');
}

function findKey(row: any, candidates: string[]): string | null {
  if (!row || typeof row !== 'object') return null;
  const keys = Object.keys(row);
  for (const c of candidates) {
    const cn = normalizeHeader(c);
    for (const k of keys) {
      if (normalizeHeader(k) === cn) return k;
    }
  }
  return null;
}

// ═══════════════════════════════════════════
// CSV parser (handles , ; TAB)
// ═══════════════════════════════════════════
function detectDelimiter(text: string): string {
  const first = text.split(/\r?\n/)[0] || '';
  const counts = {
    ',': (first.match(/,/g) || []).length,
    ';': (first.match(/;/g) || []).length,
    '\t': (first.match(/\t/g) || []).length,
  };
  let best = ',';
  let max = 0;
  for (const [d, n] of Object.entries(counts)) {
    if (n > max) { max = n; best = d; }
  }
  return best;
}

function parseCSVLine(line: string, delim: string): string[] {
  const out: string[] = [];
  let cur = '';
  let inQuote = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuote) {
      if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
      else if (ch === '"') inQuote = false;
      else cur += ch;
    } else {
      if (ch === '"') inQuote = true;
      else if (ch === delim) { out.push(cur); cur = ''; }
      else cur += ch;
    }
  }
  out.push(cur);
  return out;
}

function parseCSV(text: string): any[] {
  const clean = text.replace(/^\uFEFF/, '');
  const lines = clean.split(/\r?\n/).filter(l => l.trim().length > 0);
  if (lines.length < 2) return [];

  const delim = detectDelimiter(clean);
  const headers = parseCSVLine(lines[0], delim).map(h => h.trim());
  const rows: any[] = [];

  for (let i = 1; i < lines.length; i++) {
    const vals = parseCSVLine(lines[i], delim);
    const row: any = {};
    headers.forEach((h, idx) => {
      row[h || `col${idx}`] = (vals[idx] ?? '').toString().trim();
    });
    rows.push(row);
  }
  return rows;
}

// ═══════════════════════════════════════════
// MAIN HANDLER
// ═══════════════════════════════════════════
export async function POST(req: Request) {
  console.log('[upload] === START ===');

  try {
    // ── Parse form data
    let form: FormData;
    try {
      form = await req.formData();
    } catch (e: any) {
      return fail('Could not read form data', e.message);
    }

    const file = form.get('file') as File | null;
    if (!file) return fail('No file uploaded');

    console.log('[upload] file:', file.name, '| size:', file.size, '| type:', file.type);

    // ── Basic file checks
    if (file.size === 0) return fail('File is empty (0 bytes)');
    if (file.size > 15 * 1024 * 1024) return fail('File too large (max 15MB)');

    const name = (file.name || '').toLowerCase();
    const isCSV = name.endsWith('.csv');
    const isXLS = name.endsWith('.xlsx') || name.endsWith('.xls');

    if (!isCSV && !isXLS) {
      return fail('Unsupported file type. Use .xlsx, .xls, or .csv');
    }

    // ── Read buffer
    let buf: Buffer;
    try {
      buf = Buffer.from(await file.arrayBuffer());
    } catch (e: any) {
      return fail('Could not read file content', e.message);
    }

    // ── Parse into rows
    let rows: any[] = [];
    let parser = 'unknown';

    if (isCSV) {
      try {
        rows = parseCSV(buf.toString('utf-8'));
        parser = 'csv';
      } catch (e: any) {
        return fail('CSV parse failed', e.message);
      }
    } else {
      // Excel — try XLSX
      try {
        const XLSX = await import('xlsx');
        const wb = XLSX.read(buf, { type: 'buffer' });
        const sheetName = wb.SheetNames?.[0];
        if (!sheetName) return fail('Excel file has no worksheets');

        const sheet = wb.Sheets[sheetName];
        if (!sheet) return fail('Could not read first worksheet');

        rows = XLSX.utils.sheet_to_json(sheet, {
          defval: '',
          raw: false,
        });
        parser = 'xlsx';
      } catch (e: any) {
        console.error('[upload] XLSX parse error:', e.message);
        return fail('Failed to parse Excel file. Try saving as CSV and uploading again.', e.message);
      }
    }

    if (!Array.isArray(rows) || rows.length === 0) {
      return fail('File has no data rows');
    }

    console.log('[upload] parsed', rows.length, 'rows via', parser);

    // ── Find email column (case-insensitive)
    const sampleRow = rows[0];
    const emailKey = findKey(sampleRow, [
      'email', 'e-mail', 'e_mail', 'email address', 'emailaddress',
      'mail', 'email id', 'emailid'
    ]);

    if (!emailKey) {
      const available = Object.keys(sampleRow || {});
      return fail(
        'Email column not found',
        `Detected columns: ${available.join(', ') || 'none'}. Expected a column named "Email".`
      );
    }

    console.log('[upload] email column:', emailKey);

    // ── Name / Company / Phone / City columns (optional)
    const nameKey = findKey(sampleRow, ['name', 'full name', 'fullname', 'first name', 'firstname']);
    const companyKey = findKey(sampleRow, ['company', 'organization', 'organisation', 'org', 'business']);
    const phoneKey = findKey(sampleRow, ['phone', 'mobile', 'contact', 'phone number', 'phonenumber']);
    const cityKey = findKey(sampleRow, ['city', 'location', 'town']);

    // ── Process rows
    const seen = new Set<string>();
    const valid: any[] = [];
    const duplicates: string[] = [];
    const invalidList: { email: string; reason: string }[] = [];
    let invalid = 0;

    for (const row of rows) {
      const raw = row?.[emailKey];
      const email = cleanEmail(raw);

      if (!email) { invalid++; continue; }

      if (!isValidEmail(email)) {
        invalid++;
        invalidList.push({ email, reason: 'Invalid format' });
        continue;
      }

      if (seen.has(email)) {
        duplicates.push(email);
        continue;
      }
      seen.add(email);

      valid.push({
        email,
        name: nameKey ? String(row[nameKey] || '').trim() : '',
        company: companyKey ? String(row[companyKey] || '').trim() : '',
        phone: phoneKey ? String(row[phoneKey] || '').trim() : '',
        city: cityKey ? String(row[cityKey] || '').trim() : '',
      });
    }

    console.log('[upload] processed: valid=%d, invalid=%d, dup=%d', valid.length, invalid, duplicates.length);

    // ── Save to DB in batches (safe)
    let saved = 0;
    let dbError: string | null = null;
    if (valid.length > 0) {
      try {
        const { prisma } = await import('@/lib/prisma');
        const BATCH = 100;

        for (let i = 0; i < valid.length; i += BATCH) {
          const slice = valid.slice(i, i + BATCH);
          try {
            await prisma.$transaction(
              slice.map(v =>
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
              ),
              { timeout: 20000 }
            );
            saved += slice.length;
          } catch (e: any) {
            console.warn('[upload] batch save failed:', e.message);
            dbError = e.message;
            // Continue with next batch
          }
        }
      } catch (e: any) {
        console.warn('[upload] DB module failed:', e.message);
        dbError = e.message;
      }
    }

    // ── FINAL JSON RESPONSE
    return ok({
      parser,
      message: `${valid.length} valid email(s) loaded`,
      total: rows.length,
      imported: valid.length,
      saved,
      duplicates: duplicates.length,
      duplicateList: duplicates.slice(0, 200),
      invalid,
      invalidList: invalidList.slice(0, 200),
      contacts: valid,
      dbError,
    });
  } catch (err: any) {
    console.error('[upload] FATAL:', err);
    return fail('Server error: ' + (err?.message || 'unknown'), err?.stack?.slice(0, 300), 500);
  }
}
