#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🛡️ BULLETPROOF UPLOAD — Full Rewrite"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Ensure XLSX dependency
# ==========================================
echo "📦 [1/5] Ensuring XLSX dependency..."

node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.dependencies = pkg.dependencies || {};
pkg.dependencies.xlsx = '^0.18.5';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ xlsx in dependencies');
NODEEOF

# ==========================================
# 2. BULLETPROOF API ROUTE
# ==========================================
echo ""
echo "📝 [2/5] Writing bulletproof API route..."

mkdir -p app/api/contacts/upload

cat > app/api/contacts/upload/route.ts <<'TSEOF'
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
TSEOF
sed -i 's/\r$//' app/api/contacts/upload/route.ts
echo "   ✅ Bulletproof API route"

# ==========================================
# 3. FRONTEND — Safe response parser
# ==========================================
echo ""
echo "📝 [3/5] Rewriting campaign page with safe parser..."

mkdir -p app/campaigns/new

cat > app/campaigns/new/page.tsx <<'TSXEOF'
'use client';
import { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

type Contact = { email: string; name?: string; company?: string };
type InvalidRow = { email: string; reason: string };

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ═══════════════════════════════════════════
// SAFE FETCH — never blindly parse JSON
// ═══════════════════════════════════════════
async function safeFetch(url: string, init: RequestInit): Promise<any> {
  const res = await fetch(url, init);

  const contentType = res.headers.get('content-type') || '';
  const rawText = await res.text();

  let data: any;
  if (contentType.includes('application/json')) {
    try {
      data = JSON.parse(rawText);
    } catch (e) {
      console.error('Invalid JSON:', rawText.slice(0, 300));
      throw new Error('Server returned invalid JSON. ' + rawText.slice(0, 150));
    }
  } else {
    // Non-JSON response (HTML error page?)
    console.error('Non-JSON response:', rawText.slice(0, 300));
    // Try to parse anyway
    try {
      data = JSON.parse(rawText);
    } catch {
      throw new Error(
        rawText.slice(0, 200).trim() ||
        `Server error (${res.status} ${res.statusText})`
      );
    }
  }

  if (!res.ok) {
    throw new Error(
      data?.error ||
      data?.message ||
      `Request failed (${res.status})`
    );
  }

  return data;
}

export default function NewCampaign() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('Campaign ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [batchLimit, setBatchLimit] = useState(1);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [fileStats, setFileStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgType, setMsgType] = useState<'info' | 'error' | 'success'>('info');
  const [spamReport, setSpamReport] = useState<any>(null);
  const [manualEmails, setManualEmails] = useState('');
  const [invalidRows, setInvalidRows] = useState<InvalidRow[]>([]);
  const [duplicateEmails, setDuplicateEmails] = useState<string[]>([]);
  const [testEmail, setTestEmail] = useState('');
  const [testSending, setTestSending] = useState(false);
  const [senders, setSenders] = useState<any[]>([]);
  const [uploadStatus, setUploadStatus] = useState<'idle' | 'uploading' | 'done' | 'error'>('idle');
  const [uploadProgress, setUploadProgress] = useState(0);

  // Load senders
  useEffect(() => {
    fetch('/api/senders')
      .then(r => r.json())
      .then(j => {
        const list = Array.isArray(j) ? j.filter((x: any) => x.status === 'CONNECTED') : [];
        setSenders(list);
      })
      .catch(() => {});
  }, []);

  // Auto-parse manual emails
  const manualParsed = useMemo(() => {
    const lines = manualEmails.split(/[\n,;]+/).map(l => l.trim()).filter(Boolean);
    const valid: Contact[] = [];
    const invalid: InvalidRow[] = [];
    const seen = new Set<string>();

    for (const line of lines) {
      const parts = line.split(/[,|\t]/).map(p => p.trim());
      const email = parts[0]?.toLowerCase();
      if (!email) continue;
      if (seen.has(email)) continue;
      seen.add(email);

      if (!EMAIL_RE.test(email)) {
        invalid.push({ email, reason: 'Invalid format' });
        continue;
      }
      valid.push({ email, name: parts[1] || '', company: parts[2] || '' });
    }
    return { valid, invalid };
  }, [manualEmails]);

  // Merge: file + manual (dedupe)
  const allContacts = useMemo(() => {
    const map = new Map<string, Contact>();
    for (const c of contacts) map.set(c.email.toLowerCase(), c);
    for (const c of manualParsed.valid) map.set(c.email.toLowerCase(), c);
    return Array.from(map.values());
  }, [contacts, manualParsed.valid]);

  const allInvalid = useMemo(() => {
    const map = new Map<string, InvalidRow>();
    for (const r of invalidRows) map.set(r.email, r);
    for (const r of manualParsed.invalid) map.set(r.email, r);
    return Array.from(map.values());
  }, [invalidRows, manualParsed.invalid]);

  const showMsg = (text: string, type: 'info' | 'error' | 'success' = 'info') => {
    setMsg(text);
    setMsgType(type);
  };

  // ═══════════════════════════════════════════
  // FILE UPLOAD — with safe parser + progress
  // ═══════════════════════════════════════════
  const uploadFile = async (f: File) => {
    setUploadStatus('uploading');
    setUploadProgress(0);
    setBusy(true);
    showMsg('⏳ Uploading and processing...', 'info');

    const fd = new FormData();
    fd.append('file', f);

    // Progress simulation
    const progInterval = setInterval(() => {
      setUploadProgress(p => Math.min(90, p + 8));
    }, 200);

    try {
      const j = await safeFetch('/api/contacts/upload', {
        method: 'POST',
        body: fd,
      });

      clearInterval(progInterval);
      setUploadProgress(100);

      console.log('[upload] response:', j);

      if (!j.success) {
        throw new Error(j.error || 'Upload failed');
      }

      // Success
      setContacts(j.contacts || []);
      setFileStats({
        totalRows: j.total,
        valid: j.imported,
        invalid: j.invalid,
        duplicates: j.duplicates,
        suppressed: 0,
      });
      setDuplicateEmails(j.duplicateList || []);
      setInvalidRows((j.invalidList || []).map((r: any) => ({
        email: r.email,
        reason: r.reason || 'Invalid',
      })));
      setUploadStatus('done');

      const dupMsg = j.duplicates > 0 ? ` · 🚫 ${j.duplicates} duplicates removed` : '';
      showMsg(`✅ ${j.imported} valid email(s) loaded${dupMsg}`, 'success');
    } catch (e: any) {
      clearInterval(progInterval);
      setUploadStatus('error');
      setUploadProgress(0);
      console.error('[upload] failed:', e);
      showMsg('❌ ' + (e.message || 'Upload failed'), 'error');
    }
    setBusy(false);
  };

  // ═══════════════════════════════════════════
  // Invalid → Valid
  // ═══════════════════════════════════════════
  const moveInvalidToValid = (email: string) => {
    setContacts(prev => [...prev, { email: email.toLowerCase(), name: '', company: '' }]);
    setInvalidRows(prev => prev.filter(r => r.email !== email));
  };

  const moveAllInvalidToValid = () => {
    const add = allInvalid.map(r => ({ email: r.email.toLowerCase(), name: '', company: '' }));
    setContacts(prev => [...prev, ...add]);
    setInvalidRows([]);
  };

  const removeContact = (email: string) => {
    setContacts(prev => prev.filter(c => c.email.toLowerCase() !== email.toLowerCase()));
  };

  const clearAll = () => {
    setContacts([]);
    setFileStats(null);
    setInvalidRows([]);
    setManualEmails('');
    setDuplicateEmails([]);
    setUploadStatus('idle');
    setUploadProgress(0);
    setMsg('');
  };

  // ═══════════════════════════════════════════
  // TEST EMAIL
  // ═══════════════════════════════════════════
  const sendTest = async () => {
    if (!testEmail || !EMAIL_RE.test(testEmail)) {
      showMsg('❌ Valid test email daalo', 'error');
      return;
    }
    if (!subject || !html) {
      showMsg('❌ Subject aur HTML chahiye', 'error');
      return;
    }
    setTestSending(true);
    try {
      const j = await safeFetch('/api/test-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: testEmail, subject, html }),
      });
      showMsg(`✅ Test sent from ${j.sender}`, 'success');
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
    }
    setTestSending(false);
  };

  // ═══════════════════════════════════════════
  // SPAM CHECK
  // ═══════════════════════════════════════════
  const checkSpam = async () => {
    if (!subject || !html) {
      showMsg('❌ Subject aur HTML chahiye', 'error');
      return;
    }
    setBusy(true);
    try {
      const j = await safeFetch('/api/anti-spam/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, html }),
      });
      setSpamReport(j);
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
    }
    setBusy(false);
  };

  // ═══════════════════════════════════════════
  // LAUNCH
  // ═══════════════════════════════════════════
  const launch = async () => {
    if (!allContacts.length) { showMsg('❌ Contacts add karo', 'error'); return; }
    if (!subject.trim()) { showMsg('❌ Subject daalo', 'error'); return; }

    setBusy(true);
    showMsg('🚀 Launching campaign...', 'info');

    try {
      const created = await safeFetch('/api/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          emails: allContacts.map(c => c.email),
          batchLimit,
        }),
      });

      await safeFetch(`/api/campaigns/${created.id}/start`, { method: 'POST' });

      showMsg('✅ Campaign started!', 'success');
      setTimeout(() => router.push('/dashboard/live'), 500);
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
      setBusy(false);
    }
  };

  const hasContacts = allContacts.length > 0;
  const canGoStep2 = hasContacts;
  const canGoStep3 = subject.trim().length > 0 && html.trim().length > 0;

  const StepDot = ({ n, active, done }: { n: number; active: boolean; done: boolean }) => (
    <div style={{
      width: 34, height: 34, borderRadius: '50%',
      background: done ? 'linear-gradient(135deg,#10b981,#059669)'
        : active ? 'linear-gradient(135deg,#8b5cf6,#6366f1)'
        : 'var(--bg-subtle)',
      color: (done || active) ? '#fff' : 'var(--fg-dim)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 700, fontSize: 13,
      transition: 'all .3s',
      boxShadow: active ? '0 4px 12px rgba(139,92,246,0.35)' : 'none',
    }}>{done ? '✓' : n}</div>
  );

  return (
    <div style={{ maxWidth: 1000, margin: '0 auto' }} className="space-y-5">
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ fontSize: 'clamp(1.5rem, 4vw, 2rem)', fontWeight: 700, margin: 0 }}>📧 New Campaign</h1>
          <p style={{ color: 'var(--fg-muted)', fontSize: 13, marginTop: 4 }}>Create and launch in 4 simple steps</p>
        </div>
        <Link href="/dashboard/live" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {/* Message */}
      {msg && (
        <div style={{
          padding: 14,
          borderRadius: 12,
          fontSize: 13,
          fontWeight: 600,
          background: msgType === 'error' ? '#fef2f2' : msgType === 'success' ? '#f0fdf4' : '#f0f9ff',
          border: '1px solid ' + (msgType === 'error' ? '#fca5a5' : msgType === 'success' ? '#86efac' : '#7dd3fc'),
          color: msgType === 'error' ? '#991b1b' : msgType === 'success' ? '#065f46' : '#075985',
        }}>
          {msg}
        </div>
      )}

      {/* Steps */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {[{ n: 1, label: 'Contacts' }, { n: 2, label: 'Email' }, { n: 3, label: 'Preview' }, { n: 4, label: 'Launch' }].map((s, i) => (
          <div key={s.n} style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1 }}>
            <StepDot n={s.n} active={step === s.n} done={step > s.n} />
            <div style={{ fontSize: 12, fontWeight: step >= s.n ? 600 : 500, color: step >= s.n ? 'var(--fg)' : 'var(--fg-dim)' }} className="hidden md:block">
              {s.label}
            </div>
            {i < 3 && <div style={{ flex: 1, height: 2, background: step > s.n ? 'linear-gradient(90deg,#8b5cf6,#10b981)' : 'var(--border)' }} />}
          </div>
        ))}
      </div>

      {/* STEP 1 */}
      {step === 1 && (
        <div className="card space-y-5">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>Step 1 — Add Contacts</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>Excel upload karo YA manual type karo — dono me se koi ek kaafi hai</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
            {/* File Upload */}
            <div style={{
              padding: 20,
              border: '2px dashed',
              borderColor: uploadStatus === 'done' ? '#10b981' : uploadStatus === 'error' ? '#ef4444' : 'var(--border)',
              borderRadius: 16,
              background: uploadStatus === 'done' ? 'rgba(16,185,129,0.04)' : uploadStatus === 'error' ? 'rgba(239,68,68,0.04)' : 'var(--bg-subtle)',
              transition: 'all .3s',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <div style={{ fontSize: 24 }}>📁</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>
                    {uploadStatus === 'done' ? 'File Uploaded ✓' : 'Upload Excel / CSV'}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--fg-dim)' }}>Optional — agar file hai to</div>
                </div>
              </div>

              <input
                type="file"
                accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv"
                onChange={e => {
                  const f = e.target.files?.[0];
                  if (f) uploadFile(f);
                  e.target.value = '';
                }}
                disabled={busy}
                style={{
                  width: '100%', fontSize: 12, padding: 8,
                  borderRadius: 8, background: 'var(--bg-elevated)',
                  border: '1px solid var(--border)',
                  cursor: busy ? 'not-allowed' : 'pointer',
                }}
              />

              {uploadStatus === 'uploading' && (
                <div style={{ marginTop: 10 }}>
                  <div style={{ height: 4, background: 'rgba(15,23,42,0.08)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{
                      height: '100%', width: uploadProgress + '%',
                      background: 'linear-gradient(90deg, #8b5cf6, #10b981)',
                      transition: 'width .2s',
                    }} />
                  </div>
                  <div style={{ fontSize: 11, color: '#8b5cf6', marginTop: 6, fontWeight: 600 }}>
                    ⏳ {uploadProgress}% — processing...
                  </div>
                </div>
              )}

              {uploadStatus === 'done' && fileStats && (
                <div style={{ fontSize: 11, color: '#059669', marginTop: 8, fontWeight: 700 }}>
                  ✓ {fileStats.valid} valid email(s) loaded
                </div>
              )}
            </div>

            {/* Manual Entry */}
            <div style={{
              padding: 20,
              border: '2px dashed',
              borderColor: manualParsed.valid.length > 0 ? '#10b981' : 'var(--border)',
              borderRadius: 16,
              background: manualParsed.valid.length > 0 ? 'rgba(16,185,129,0.04)' : 'var(--bg-subtle)',
              transition: 'all .3s',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <div style={{ fontSize: 24 }}>✍️</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>Manual Entry</div>
                  <div style={{ fontSize: 11, color: 'var(--fg-dim)' }}>Type emails directly</div>
                </div>
              </div>

              <textarea
                className="input font-mono"
                style={{ fontSize: 12, minHeight: 100, resize: 'vertical' }}
                placeholder={"rahul@example.com\namit@company.com, Amit Sharma\npriya@startup.io, Priya, Acme"}
                value={manualEmails}
                onChange={e => setManualEmails(e.target.value)}
              />

              {manualParsed.valid.length > 0 && (
                <div style={{ fontSize: 11, color: '#059669', marginTop: 8, fontWeight: 700 }}>
                  ✓ {manualParsed.valid.length} valid detected
                </div>
              )}
            </div>
          </div>

          {/* Stats */}
          {fileStats && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 10 }}>
              <Stat label="TOTAL" value={fileStats.totalRows} />
              <Stat label="VALID" value={fileStats.valid} color="#10b981" />
              <Stat label="INVALID" value={fileStats.invalid} color="#ef4444" />
              <Stat label="DUPLICATES" value={fileStats.duplicates} color="#f59e0b" />
              <Stat label="SUPPRESSED" value={fileStats.suppressed} color="#6b7280" />
            </div>
          )}

          {/* Duplicates */}
          {duplicateEmails.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 13, color: '#d97706', fontWeight: 700 }}>
                  🚫 {duplicateEmails.length} duplicate email(s) removed
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
                    fontSize: 12, fontFamily: 'monospace', color: 'var(--fg-muted)',
                  }}>{em}</div>
                ))}
              </div>
            </div>
          )}

          {/* Invalid */}
          {allInvalid.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 13, color: '#dc2626', fontWeight: 700 }}>
                  ⚠️ {allInvalid.length} invalid email(s)
                </div>
                <button onClick={moveAllInvalidToValid} className="btn btn-ghost" style={{ fontSize: 12, padding: '6px 12px' }}>
                  ➡️ Move All to Valid
                </button>
              </div>
              <div style={{ maxHeight: 180, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                {allInvalid.map((row, i) => (
                  <div key={i} style={{
                    padding: '8px 12px',
                    borderBottom: i < allInvalid.length - 1 ? '1px solid var(--border)' : 'none',
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8,
                  }}>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontSize: 12, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.email}</div>
                      <div style={{ fontSize: 10, color: 'var(--fg-dim)' }}>{row.reason}</div>
                    </div>
                    <button onClick={() => moveInvalidToValid(row.email)} className="btn btn-ghost" style={{ fontSize: 11, padding: '4px 10px' }}>
                      ✓ Valid
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Merged contacts */}
          {hasContacts && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 14, color: '#10b981', fontWeight: 700 }}>
                  ✅ {allContacts.length} unique contact(s) ready
                </div>
                <button onClick={clearAll} style={{ fontSize: 11, color: '#dc2626', background: 'none', border: 'none', cursor: 'pointer', textDecoration: 'underline' }}>
                  Clear all
                </button>
              </div>

              <div style={{ maxHeight: 260, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                <table style={{ width: '100%', fontSize: 12, borderCollapse: 'collapse' }}>
                  <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0, zIndex: 1 }}>
                    <tr>
                      <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Name</th>
                      <th style={{ width: 40 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {allContacts.map((c, i) => (
                      <tr key={c.email + i} style={{ borderTop: '1px solid var(--border)' }}>
                        <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                        <td style={{ padding: 10, fontFamily: 'monospace' }}>{c.email}</td>
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.name || '—'}</td>
                        <td style={{ padding: 10 }}>
                          <button onClick={() => removeContact(c.email)} style={{ background: 'none', border: 'none', color: '#dc2626', cursor: 'pointer', fontSize: 14 }}>✕</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <button
            onClick={() => canGoStep2 && setStep(2)}
            disabled={!canGoStep2}
            className="btn btn-primary"
            style={{ width: '100%', padding: 14, fontSize: 15, opacity: canGoStep2 ? 1 : 0.5, cursor: canGoStep2 ? 'pointer' : 'not-allowed' }}
          >
            {canGoStep2
              ? `Next → Email Content (${allContacts.length} contacts)`
              : '📁 Upload file OR ✍️ type emails to continue'}
          </button>
        </div>
      )}

      {/* STEP 2 */}
      {step === 2 && (
        <div className="card space-y-4">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>Step 2 — Email Content</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>Subject aur HTML body bharo</p>
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>Subject *</label>
            <input className="input" placeholder="Hello {{name}}, quick update" value={subject} onChange={e => setSubject(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>HTML Body *</label>
            <textarea className="input font-mono" style={{ fontSize: 12, minHeight: 200, resize: 'vertical' }} value={html} onChange={e => setHtml(e.target.value)} />
          </div>

          <div style={{ padding: 16, background: 'rgba(139,92,246,0.05)', border: '1px solid rgba(139,92,246,0.2)', borderRadius: 12 }}>
            <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>📨 Test Email Send Karo</div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input className="input" style={{ flex: 1, minWidth: 200 }} type="email" placeholder="your@email.com" value={testEmail} onChange={e => setTestEmail(e.target.value)} />
              <button onClick={sendTest} disabled={testSending || !testEmail} className="btn btn-primary">
                {testSending ? '⏳ Sending…' : '📤 Send Test'}
              </button>
            </div>
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 8 }}>
              {senders.length > 0 ? `📤 Sender: ${senders[0].email}` : '⚠️ No sender connected'}
            </div>
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>🔄 Batch limit per sender (1-350)</label>
            <input type="number" className="input" style={{ maxWidth: 200 }} min={1} max={350} value={batchLimit} onChange={e => setBatchLimit(Math.min(350, Math.max(1, parseInt(e.target.value) || 1)))} />
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 4 }}>1 = Strict one-by-one · 350 = max per sender</div>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button onClick={checkSpam} disabled={busy || !subject || !html} className="btn btn-ghost">🛡️ Spam Check</button>
            <button onClick={() => setStep(1)} className="btn btn-ghost">← Back</button>
            <button onClick={() => canGoStep3 && setStep(3)} disabled={!canGoStep3} className="btn btn-primary" style={{ opacity: canGoStep3 ? 1 : 0.5 }}>
              {canGoStep3 ? 'Next → Preview' : 'Subject + HTML bharo'}
            </button>
          </div>

          {spamReport && (
            <div style={{
              border: '1px solid',
              borderColor: spamReport.blocked ? '#fca5a5' : spamReport.warning ? '#fcd34d' : '#86efac',
              background: spamReport.blocked ? '#fef2f2' : spamReport.warning ? '#fffbeb' : '#f0fdf4',
              borderRadius: 12, padding: 16,
            }}>
              <div style={{ fontWeight: 700, marginBottom: 8 }}>
                Spam Score: <span style={{ fontSize: 22, color: spamReport.blocked ? '#dc2626' : spamReport.warning ? '#d97706' : '#059669' }}>{spamReport.score}</span>
                {' '}({spamReport.blocked ? '🚫 Blocked' : spamReport.warning ? '⚠️ Warning' : '✅ Safe'})
              </div>
              {spamReport.issues?.map((iss: any, i: number) => (
                <div key={i} style={{ fontSize: 12, marginTop: 4 }}>• {iss.message} <span style={{ opacity: 0.6 }}>(+{iss.points})</span></div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* STEP 3 */}
      {step === 3 && (
        <div className="card space-y-4">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>👁️ Step 3 — Preview Recipients</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>Ye list check karo — sirf inhi emails ko message jayega</p>
          </div>

          <div style={{ background: 'linear-gradient(135deg, rgba(139,92,246,0.08), rgba(236,72,153,0.04))', border: '1px solid rgba(139,92,246,0.25)', borderRadius: 16, padding: 20 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.1em' }}>Total</div>
                <div style={{ fontSize: 26, fontWeight: 800, color: '#8b5cf6' }}>{allContacts.length}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.1em' }}>Batch</div>
                <div style={{ fontSize: 26, fontWeight: 800 }}>{batchLimit}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.1em' }}>Cycles</div>
                <div style={{ fontSize: 26, fontWeight: 800 }}>{Math.ceil(allContacts.length / Math.max(1, batchLimit))}</div>
              </div>
            </div>
          </div>

          <div style={{ border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden' }}>
            <div style={{ background: 'var(--bg-subtle)', padding: '10px 16px', fontSize: 12, color: 'var(--fg-muted)', fontWeight: 700, borderBottom: '1px solid var(--border)' }}>
              Email List ({allContacts.length})
            </div>
            <div style={{ maxHeight: 400, overflow: 'auto' }}>
              <table style={{ width: '100%', fontSize: 12 }}>
                <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0 }}>
                  <tr>
                    <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Name</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Company</th>
                  </tr>
                </thead>
                <tbody>
                  {allContacts.map((c, i) => (
                    <tr key={i} style={{ borderTop: '1px solid var(--border)' }}>
                      <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                      <td style={{ padding: 10, fontFamily: 'monospace' }}>{c.email}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.name || '—'}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(2)} className="btn btn-ghost">← Back</button>
            <button onClick={() => setStep(4)} className="btn btn-primary" style={{ flex: 1 }}>Next → Launch</button>
          </div>
        </div>
      )}

      {/* STEP 4 */}
      {step === 4 && (
        <div className="card space-y-4">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>🚀 Step 4 — Final Review</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>Sab kuch verify karo, phir launch karo</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16 }}>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Campaign</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{name}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Subject</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{subject}</div>
            </div>
            <div style={{ background: 'rgba(16,185,129,0.08)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: '#065f46', fontWeight: 700, textTransform: 'uppercase' }}>Recipients</div>
              <div style={{ fontSize: 22, fontWeight: 800, color: '#059669', marginTop: 4 }}>{allContacts.length}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Batch</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{batchLimit} per sender</div>
            </div>
          </div>

          <div style={{ background: '#fffbeb', border: '1px solid #fcd34d', borderRadius: 12, padding: 14, fontSize: 13, color: '#92400e', lineHeight: 1.5 }}>
            ⚠️ <b>Launch ke baad:</b> Live Dashboard pe redirect hoga. Worker automatically emails bhejega (sender rotation + warm-up rules ke saath).
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(3)} className="btn btn-ghost">← Back</button>
            <button onClick={launch} disabled={busy} className="btn btn-primary" style={{ flex: 1, padding: 14, fontSize: 15 }}>
              {busy ? '🚀 Launching…' : `🚀 LAUNCH CAMPAIGN — ${allContacts.length} emails`}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 12, padding: 12 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', letterSpacing: '0.1em', fontWeight: 700 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>{value?.toLocaleString() ?? 0}</div>
    </div>
  );
}
TSXEOF
sed -i 's/\r$//' app/campaigns/new/page.tsx
echo "   ✅ Campaign page rewritten with safe parser"

# ==========================================
# 4. TEST ENDPOINT — diagnostic
# ==========================================
echo ""
echo "🔍 [4/5] Creating diagnostic endpoint..."

mkdir -p app/api/debug/upload-test

cat > app/api/debug/upload-test/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const checks: any = {};

  try {
    const XLSX = await import('xlsx');
    checks.xlsx = { ok: true, version: XLSX.version };
  } catch (e: any) {
    checks.xlsx = { ok: false, error: e.message };
  }

  try {
    const { prisma } = await import('@/lib/prisma');
    const count = await prisma.contact.count();
    checks.prisma = { ok: true, contacts: count };
  } catch (e: any) {
    checks.prisma = { ok: false, error: e.message };
  }

  return NextResponse.json({
    ok: true,
    timestamp: new Date().toISOString(),
    checks,
  });
}
EOF
sed -i 's/\r$//' app/api/debug/upload-test/route.ts
echo "   ✅ Diagnostic endpoint"

# ==========================================
# 5. Git push
# ==========================================
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: bulletproof upload — safe parser, always JSON, duplicates detected"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ BULLETPROOF UPLOAD DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Key changes:"
echo "   ✓ Frontend: safeFetch() — never blindly .json()"
echo "   ✓ Backend: ALWAYS returns JSON (success + error)"
echo "   ✓ Header normalization (Email/EMAIL/e-mail)"
echo "   ✓ Duplicate detection + separate list"
echo "   ✓ Batch DB save (100 per transaction)"
echo "   ✓ Progress bar during upload"
echo "   ✓ Detailed error messages"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📊 Test flow:"
echo "   1. Hard refresh (Ctrl+Shift+R)"
echo "   2. Diagnostic: /api/debug/upload-test"
echo "   3. Then try upload — JSON error milega (never HTML)"
echo "==============================================="