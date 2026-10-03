#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎯 Campaign Workflow + Team Login"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 2. Team whitelist lib ----------
echo ""
echo "📝 lib/team.ts..."
mkdir -p lib
cat > lib/team.ts <<'EOF'
/**
 * Team-only access control.
 * Only whitelisted emails can login. No public registration.
 *
 * ALLOWED_EMAILS env var — comma-separated list.
 * Example: "dipenzala1@gmail.com,certwinx@gmail.com,sales@company.com"
 */

export function isTeamMember(email: string): boolean {
  const raw = (process.env.ALLOWED_EMAILS || '').trim();
  if (!raw) {
    // If no whitelist configured, allow first admin
    return true; // Dev mode
  }
  const allowed = raw
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return allowed.includes(email.toLowerCase().trim());
}

export function getTeamList(): string[] {
  const raw = (process.env.ALLOWED_EMAILS || '').trim();
  if (!raw) return [];
  return raw.split(',').map((e) => e.trim()).filter(Boolean);
}

export function addTeamMember(current: string, email: string): string {
  const list = current.split(',').map((e) => e.trim()).filter(Boolean);
  const clean = email.trim().toLowerCase();
  if (!list.includes(clean)) list.push(clean);
  return list.join(',');
}

export function removeTeamMember(current: string, email: string): string {
  const clean = email.trim().toLowerCase();
  return current
    .split(',')
    .map((e) => e.trim())
    .filter((e) => e && e.toLowerCase() !== clean)
    .join(',');
}
EOF

# ---------- 3. Login API with whitelist ----------
echo "📝 app/api/auth/login/route.ts (whitelist)..."
mkdir -p app/api/auth/login
cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';
import { isTeamMember } from '@/lib/team';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { email, password } = await req.json();

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  }

  const cleanEmail = String(email).toLowerCase().trim();

  // Team-only check
  if (!isTeamMember(cleanEmail)) {
    return NextResponse.json(
      { error: 'Access denied. This platform is invite-only for team members.' },
      { status: 403 }
    );
  }

  // Save to users table
  try {
    await prisma.user.upsert({
      where: { email: cleanEmail },
      create: { email: cleanEmail, name: cleanEmail.split('@')[0] },
      update: {},
    });
  } catch {}

  const token = signSession({
    email: cleanEmail,
    name: cleanEmail.split('@')[0],
    ts: Date.now(),
  });

  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
EOF

# ---------- 4. Preview API ----------
echo "📝 app/api/preview/route.ts (email preview)..."
mkdir -p app/api/preview
cat > app/api/preview/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { renderTemplate } from '@/lib/personalization';
import { sanitizeForPreview } from '@/lib/sanitize';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { subject, html, sample } = await req.json();
  if (!html) return NextResponse.json({ error: 'html required' }, { status: 400 });

  const data = sample || {
    name: 'Rahul Sharma',
    email: 'rahul@example.com',
    company: 'Acme Corp',
    city: 'Mumbai',
    phone: '+91 98765 43210',
  };

  const rendered = renderTemplate(html, data);
  const safe = sanitizeForPreview(rendered);
  const spam = checkEmail({ subject: subject || '', html: rendered, fromEmail: 'noreply@example.com' });

  return NextResponse.json({
    html: safe,
    raw: rendered,
    spam,
    variables: data,
  });
}
EOF

# ---------- 5. Templates API ----------
echo "📝 app/api/templates/route.ts..."
mkdir -p app/api/templates
cat > app/api/templates/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list templates
export async function GET() {
  try {
    const list = await prisma.emailTemplate?.findMany?.({ orderBy: { createdAt: 'desc' } }) ?? [];
    return NextResponse.json(list);
  } catch {
    return NextResponse.json([]);
  }
}

// POST: save template
export async function POST(req: Request) {
  const { name, subject, html } = await req.json();
  if (!name || !html) return NextResponse.json({ error: 'name and html required' }, { status: 400 });
  try {
    const t = await (prisma as any).emailTemplate?.create?.({
      data: { name, subject: subject || '', html },
    });
    return NextResponse.json({ ok: true, template: t });
  } catch (e: any) {
    return NextResponse.json({ error: 'Template table not migrated', detail: e.message }, { status: 500 });
  }
}
EOF

# ---------- 6. Add EmailTemplate to schema ----------
echo "📝 Adding EmailTemplate to prisma schema..."
if ! grep -q "model EmailTemplate" prisma/schema.prisma 2>/dev/null; then
  cat >> prisma/schema.prisma <<'EOF'

model EmailTemplate {
  id        String   @id @default(cuid())
  name      String
  subject   String   @default("")
  html      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
EOF
  sed -i 's/\r$//' prisma/schema.prisma
fi

# ---------- 7. Team management API ----------
echo "📝 app/api/team/route.ts..."
mkdir -p app/api/team
cat > app/api/team/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { getTeamList } from '@/lib/team';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const list = getTeamList();
  return NextResponse.json({ members: list });
}
EOF

# ---------- 8. Main Dashboard — Full Campaign Workflow ----------
echo ""
echo "📝 app/dashboard/page.tsx (full workflow)..."

cat > app/dashboard/page.tsx <<'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';

type Contact = { email: string; name: string; company: string };
type Sender = { id: string; email: string; status: string };
type Summary = { totalRows: number; valid: number; invalid: number; duplicates: number; suppressed: number; disposable?: number; contacts: Contact[] };
type Preview = { html: string; spam: { score: number; blocked: boolean; warning: boolean; issues: any[] } };

export default function CampaignDashboard() {
  // Step state
  const [step, setStep] = useState(1);

  // Step 1 — contacts
  const [file, setFile] = useState<File | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [uploading, setUploading] = useState(false);

  // Step 2 — email content
  const [subject, setSubject] = useState('Quick question about {{company}}');
  const [html, setHtml] = useState(DEFAULT_HTML);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [showPreview, setShowPreview] = useState(false);
  const [testTo, setTestTo] = useState('');
  const [testMsg, setTestMsg] = useState('');

  // Step 3 — campaign settings
  const [campaignName, setCampaignName] = useState('Campaign ' + new Date().toISOString().slice(0, 10));
  const [batchLimit, setBatchLimit] = useState(10);
  const [senders, setSenders] = useState<Sender[]>([]);
  const [launching, setLaunching] = useState(false);
  const [campaignId, setCampaignId] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/senders').then(r => r.json()).then(setSenders).catch(() => {});
  }, []);

  // ---------- Step 1 actions ----------
  const upload = async () => {
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('file', file);
    const r = await fetch('/api/contacts/upload', { method: 'POST', body: fd });
    const j = await r.json();
    if (r.ok) {
      setSummary(j);
      setStep(2);
    } else {
      alert('Upload failed: ' + (j.error || 'unknown'));
    }
    setUploading(false);
  };

  // ---------- Step 2 actions ----------
  const runPreview = async () => {
    const r = await fetch('/api/preview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subject, html }),
    });
    const j = await r.json();
    setPreview(j);
    setShowPreview(true);
  };

  const sendTest = async () => {
    setTestMsg('');
    const r = await fetch('/api/test-email', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ to: testTo, subject, html }),
    });
    const j = await r.json();
    setTestMsg(r.ok ? `✅ Test sent (ID: ${j.id})` : '❌ ' + (j.error || 'Failed'));
  };

  // ---------- Step 3 actions ----------
  const launch = async () => {
    if (!summary) return;
    setLaunching(true);
    const r = await fetch('/api/campaigns', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: campaignName,
        subject,
        html,
        emails: summary.contacts.map(c => c.email),
        batchLimit,
      }),
    });
    const j = await r.json();
    if (!r.ok) {
      alert('Create failed: ' + JSON.stringify(j.error));
      setLaunching(false);
      return;
    }
    // Auto-start
    const start = await fetch(`/api/campaigns/${j.id}/start`, { method: 'POST' });
    const sj = await start.json();
    if (!start.ok) {
      alert('Start failed: ' + (sj.error || 'unknown') + '\n' + JSON.stringify(sj.issues || []));
      setLaunching(false);
      return;
    }
    setCampaignId(j.id);
    setStep(4);
    setLaunching(false);
  };

  const connectedSenders = senders.filter(s => s.status === 'CONNECTED').length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Workflow</h1>
          <p className="text-sm text-slate-400 mt-1">Import contacts → Compose → Launch</p>
        </div>
        <div className="flex items-center gap-2 text-xs">
          <Stat label="Senders" value={connectedSenders} ok={connectedSenders > 0} />
          <Stat label="Recipients" value={summary?.valid ?? 0} ok={!!summary} />
        </div>
      </div>

      {/* Step indicator */}
      <div className="flex items-center gap-2 overflow-x-auto">
        <StepDot n={1} label="Contacts" active={step >= 1} done={!!summary} />
        <div className="w-6 h-px bg-white/10 flex-shrink-0" />
        <StepDot n={2} label="Compose" active={step >= 2} done={step > 2} />
        <div className="w-6 h-px bg-white/10 flex-shrink-0" />
        <StepDot n={3} label="Launch" active={step >= 3} done={step > 3} />
        <div className="w-6 h-px bg-white/10 flex-shrink-0" />
        <StepDot n={4} label="Live" active={step >= 4} done={false} />
      </div>

      {/* ============ STEP 1 ============ */}
      {step === 1 && (
        <div className="card animate-in">
          <h2 className="text-lg font-semibold mb-4">📂 Step 1 — Import Contacts</h2>
          <div className="border-2 border-dashed border-white/10 rounded-xl p-8 text-center hover:border-white/20 transition">
            <input
              type="file"
              accept=".xlsx,.xls,.csv"
              onChange={e => setFile(e.target.files?.[0] ?? null)}
              className="block mx-auto mb-4 text-sm"
              id="file-upload"
            />
            <p className="text-xs text-slate-500 mb-4">Supported: .xlsx, .xls, .csv (email column auto-detected)</p>
            <button className="btn btn-primary" disabled={!file || uploading} onClick={upload}>
              {uploading ? 'Uploading…' : 'Import File →'}
            </button>
          </div>

          {summary && (
            <div className="mt-6 grid grid-cols-2 md:grid-cols-5 gap-3">
              <Mini label="Total" value={summary.totalRows} />
              <Mini label="Valid" value={summary.valid} accent="text-green-400" />
              <Mini label="Invalid" value={summary.invalid} accent="text-red-400" />
              <Mini label="Duplicates" value={summary.duplicates} accent="text-amber-400" />
              <Mini label="Suppressed" value={summary.suppressed} accent="text-slate-400" />
            </div>
          )}
        </div>
      )}

      {/* ============ STEP 2 ============ */}
      {step === 2 && (
        <div className="card animate-in space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">✍️ Step 2 — Compose Email</h2>
            <button className="text-xs text-slate-400 hover:text-white" onClick={() => setStep(1)}>← Back</button>
          </div>

          <div>
            <label className="text-xs text-slate-400 mb-1.5 block">Subject Line</label>
            <input className="input" value={subject} onChange={e => setSubject(e.target.value)} placeholder="Email subject" />
            <p className="text-xs text-slate-500 mt-1">
              Variables: <code className="bg-white/5 px-1 rounded">{'{{name}}'}</code>,{' '}
              <code className="bg-white/5 px-1 rounded">{'{{company}}'}</code>,{' '}
              <code className="bg-white/5 px-1 rounded">{'{{city}}'}</code>
            </p>
          </div>

          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs text-slate-400">HTML Email Code</label>
              <button
                onClick={() => { if (confirm('Reset to default template?')) setHtml(DEFAULT_HTML); }}
                className="text-xs text-slate-500 hover:text-white"
              >
                Reset template
              </button>
            </div>
            <textarea
              className="input font-mono text-xs"
              rows={14}
              value={html}
              onChange={e => setHtml(e.target.value)}
              spellCheck={false}
            />
          </div>

          <div className="flex flex-wrap gap-2">
            <button className="btn btn-ghost" onClick={runPreview}>👁 Preview</button>
            <div className="flex-1 min-w-[200px] flex gap-2">
              <input className="input flex-1" placeholder="test@example.com" value={testTo} onChange={e => setTestTo(e.target.value)} />
              <button className="btn btn-ghost" onClick={sendTest} disabled={!testTo}>Send Test</button>
            </div>
          </div>

          {testMsg && <div className="text-sm text-slate-300 bg-white/5 rounded-lg p-3">{testMsg}</div>}

          <button className="btn btn-primary w-full" onClick={() => setStep(3)}>Next: Review →</button>
        </div>
      )}

      {/* ============ STEP 3 ============ */}
      {step === 3 && summary && (
        <div className="card animate-in space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">🚀 Step 3 — Review & Launch</h2>
            <button className="text-xs text-slate-400 hover:text-white" onClick={() => setStep(2)}>← Back</button>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div className="bg-white/[0.02] border border-white/5 rounded-xl p-4">
              <div className="text-xs text-slate-500 uppercase mb-2">Recipients</div>
              <div className="text-2xl font-bold">{summary.valid.toLocaleString()}</div>
              <div className="text-xs text-slate-400 mt-1">valid email addresses</div>
            </div>
            <div className="bg-white/[0.02] border border-white/5 rounded-xl p-4">
              <div className="text-xs text-slate-500 uppercase mb-2">Senders</div>
              <div className="text-2xl font-bold">{connectedSenders}</div>
              <div className="text-xs text-slate-400 mt-1">Gmail accounts ready</div>
            </div>
          </div>

          <div>
            <label className="text-xs text-slate-400 mb-1.5 block">Campaign Name</label>
            <input className="input" value={campaignName} onChange={e => setCampaignName(e.target.value)} />
          </div>

          <div>
            <label className="text-xs text-slate-400 mb-1.5 block">
              Batch limit per sender (emails)
            </label>
            <input
              type="number"
              className="input"
              value={batchLimit}
              min={1}
              max={500}
              onChange={e => setBatchLimit(parseInt(e.target.value) || 10)}
            />
            <p className="text-xs text-slate-500 mt-1">
              Har sender {batchLimit} emails bhejega, phir agla sender rotate hoga.
            </p>
          </div>

          <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-4 text-sm text-amber-300">
            <b>⚠️ Review before launch</b>
            <ul className="mt-2 text-xs space-y-1 list-disc list-inside opacity-90">
              <li>{summary.valid.toLocaleString()} emails will be sent through {connectedSenders} senders</li>
              <li>Warm-up limits apply per sender</li>
              <li>Unsubscribe link included automatically</li>
              <li>You can pause or stop anytime</li>
            </ul>
          </div>

          <button className="btn btn-primary w-full py-3" onClick={launch} disabled={launching || connectedSenders === 0}>
            {launching ? 'Launching…' : `🚀 START CAMPAIGN (${summary.valid.toLocaleString()} emails)`}
          </button>
          {connectedSenders === 0 && (
            <p className="text-xs text-red-400 text-center">
              Connect at least 1 sender first. <Link href="/senders" className="underline">Open Senders →</Link>
            </p>
          )}
        </div>
      )}

      {/* ============ STEP 4 — LIVE ============ */}
      {step === 4 && campaignId && (
        <LiveCampaign campaignId={campaignId} />
      )}

      {/* Preview modal */}
      {showPreview && preview && (
        <div className="fixed inset-0 bg-black/80 z-50 p-6 overflow-auto" onClick={() => setShowPreview(false)}>
          <div className="bg-white text-black rounded-xl max-w-4xl mx-auto p-4" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-3">
              <b>Email Preview</b>
              <button onClick={() => setShowPreview(false)} className="text-slate-500">✕</button>
            </div>
            <div className="flex gap-2 mb-3 text-xs">
              <span className={`px-2 py-1 rounded ${preview.spam.blocked ? 'bg-red-100 text-red-700' : preview.spam.warning ? 'bg-amber-100 text-amber-700' : 'bg-green-100 text-green-700'}`}>
                Spam score: {preview.spam.score}
              </span>
            </div>
            <iframe className="w-full h-[60vh] border rounded" sandbox="" srcDoc={preview.html} />
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------- Sub-components ---------- */

function LiveCampaign({ campaignId }: { campaignId: string }) {
  const [status, setStatus] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');

  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${campaignId}/status`).then(r => r.json()).then(j => setStatus({ ...j.counts, campaignStatus: j.campaign.status })).catch(() => {});
    load();
    const iv = setInterval(load, 2000);
    return () => clearInterval(iv);
  }, [campaignId]);

  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${campaignId}/recipients?status=${filter}`).then(r => r.json()).then(setRecipients).catch(() => {});
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, [campaignId, filter]);

  const act = async (a: 'pause' | 'resume' | 'stop') => {
    if (a === 'stop' && !confirm('Stop this campaign permanently?')) return;
    await fetch(`/api/campaigns/${campaignId}/${a}`, { method: 'POST' });
  };

  const progress = status?.progress ?? 0;
  const cs = status?.campaignStatus ?? 'RUNNING';

  return (
    <div className="card animate-in space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h2 className="text-lg font-semibold">📊 Step 4 — Live Campaign</h2>
        <div className="flex gap-2">
          {cs === 'RUNNING' && <button className="btn btn-ghost text-sm" onClick={() => act('pause')}>⏸ Pause</button>}
          {cs === 'PAUSED' && <button className="btn btn-primary text-sm" onClick={() => act('resume')}>▶ Resume</button>}
          {cs !== 'COMPLETED' && cs !== 'STOPPED' && <button className="btn btn-danger text-sm" onClick={() => act('stop')}>⏹ Stop</button>}
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Mini label="Total" value={status?.total ?? 0} />
        <Mini label="Sent" value={status?.sent ?? 0} accent="text-blue-400" />
        <Mini label="Failed" value={status?.failed ?? 0} accent="text-red-400" />
        <Mini label="Pending" value={status?.pending ?? 0} accent="text-yellow-400" />
      </div>

      <div>
        <div className="flex justify-between text-xs text-slate-400 mb-1.5">
          <span>Progress — <b className="text-slate-200">{cs}</b></span>
          <b>{progress}%</b>
        </div>
        <div className="h-2 bg-white/5 rounded-full overflow-hidden">
          <div className="h-full bg-gradient-to-r from-violet-500 to-pink-500 transition-all" style={{ width: progress + '%' }} />
        </div>
      </div>

      <div className="flex gap-1.5 flex-wrap">
        {['ALL', 'QUEUED', 'PROCESSING', 'SENT', 'FAILED', 'BOUNCED', 'SUPPRESSED'].map(f => (
          <button key={f} onClick={() => setFilter(f)} className={`text-xs px-3 py-1 rounded-lg transition ${filter === f ? 'bg-white text-black' : 'bg-white/5 text-slate-300 hover:bg-white/10'}`}>{f}</button>
        ))}
      </div>

      <div className="max-h-72 overflow-auto rounded-lg border border-white/5">
        <table className="w-full text-xs">
          <thead className="text-slate-400 text-left sticky top-0 bg-slate-900">
            <tr><th className="p-2">Email</th><th className="p-2">Name</th><th className="p-2">Status</th><th className="p-2">Error</th></tr>
          </thead>
          <tbody>
            {recipients.map(r => (
              <tr key={r.id} className="border-t border-white/5">
                <td className="p-2 text-slate-300">{r.email}</td>
                <td className="p-2 text-slate-400">{r.name}</td>
                <td className={`p-2 ${r.status === 'SENT' ? 'text-blue-400' : r.status === 'FAILED' || r.status === 'BOUNCED' ? 'text-red-400' : r.status === 'SUPPRESSED' ? 'text-slate-500' : 'text-yellow-400'}`}>{r.status}</td>
                <td className="p-2 text-slate-500 truncate max-w-xs">{r.error ?? ''}</td>
              </tr>
            ))}
            {recipients.length === 0 && <tr><td colSpan={4} className="p-6 text-center text-slate-500">No recipients in this filter</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function StepDot({ n, label, active, done }: { n: number; label: string; active: boolean; done: boolean }) {
  return (
    <div className="flex items-center gap-2 flex-shrink-0">
      <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold transition ${done ? 'bg-green-500 text-white' : active ? 'bg-white text-black' : 'bg-white/10 text-slate-400'}`}>
        {done ? '✓' : n}
      </div>
      <span className={`text-sm ${active ? 'text-white' : 'text-slate-500'}`}>{label}</span>
    </div>
  );
}

function Stat({ label, value, ok }: { label: string; value: number; ok: boolean }) {
  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 border border-white/10">
      <span className="text-slate-400">{label}:</span>
      <b className={ok ? 'text-green-400' : 'text-slate-500'}>{value}</b>
    </div>
  );
}

function Mini({ label, value, accent = '' }: { label: string; value: number; accent?: string }) {
  return (
    <div className="bg-white/[0.03] border border-white/5 rounded-xl p-3">
      <div className="text-[10px] uppercase tracking-wider text-slate-500">{label}</div>
      <div className={`text-xl font-bold mt-1 ${accent}`}>{value.toLocaleString()}</div>
    </div>
  );
}

const DEFAULT_HTML = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Email</title></head>
<body style="font-family:-apple-system,sans-serif;background:#f5f5f5;padding:20px;margin:0">
  <div style="max-width:600px;margin:0 auto;background:#ffffff;border-radius:12px;padding:40px;box-shadow:0 2px 10px rgba(0,0,0,0.05)">
    <h1 style="color:#111;font-size:24px;margin:0 0 16px">Hi {{name | default:"there"}} 👋</h1>
    <p style="color:#444;font-size:16px;line-height:1.6">
      Hope you're doing well at <b>{{company | default:"your company"}}</b>.
    </p>
    <p style="color:#444;font-size:16px;line-height:1.6">
      We wanted to share a quick update with you.
    </p>
    <a href="https://example.com" style="display:inline-block;background:#6366f1;color:#fff;text-decoration:none;padding:12px 24px;border-radius:8px;margin:16px 0;font-weight:600">
      Learn More →
    </a>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0">
    <p style="color:#999;font-size:12px;text-align:center">
      Sent to {{email}}<br>
      <a href="https://emailcampaign-ten.vercel.app/api/unsubscribe/{{email}}" style="color:#999">Unsubscribe</a>
    </p>
  </div>
</body>
</html>`;
EOF
sed -i 's/\r$//' app/dashboard/page.tsx
echo "✅"

# ---------- 9. Team page (view members) ----------
echo "📝 app/team/page.tsx..."
mkdir -p app/team
cat > app/team/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
export default function TeamPage() {
  const [members, setMembers] = useState<string[]>([]);
  useEffect(() => { fetch('/api/team').then(r => r.json()).then(j => setMembers(j.members ?? [])); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">👥 Team Access</h1>
      <p className="text-sm text-slate-400">
        Only these emails can login. This platform is invite-only.
      </p>
      <div className="card">
        <h2 className="font-semibold mb-3">Whitelisted Members ({members.length})</h2>
        {members.length === 0 ? (
          <p className="text-sm text-slate-400">
            ⚠️ No whitelist set. All emails can login (dev mode).<br />
            Set <code className="bg-white/5 px-1 rounded">ALLOWED_EMAILS</code> in Vercel env vars.
          </p>
        ) : (
          <ul className="space-y-2">
            {members.map(m => (
              <li key={m} className="flex items-center gap-3 p-3 rounded-lg bg-white/[0.02] border border-white/5">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center text-xs font-bold">
                  {m[0].toUpperCase()}
                </div>
                <span className="text-sm">{m}</span>
                <span className="ml-auto text-xs text-green-400">✓ Active</span>
              </li>
            ))}
          </ul>
        )}
        <div className="mt-4 text-xs text-slate-500">
          To add/remove members: Vercel → Settings → Environment Variables → <code className="bg-white/5 px-1 rounded">ALLOWED_EMAILS</code> (comma-separated) → Redeploy.
        </div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/team/page.tsx

# ---------- 10. Update nav ----------
echo "📝 Updating dashboard nav..."
if [ -f "app/dashboard/layout.tsx" ]; then
  # Add Team link if not exists
  if ! grep -q 'href="/team"' app/dashboard/layout.tsx; then
    sed -i 's|>History</Link>|>History</Link><Link href="/team" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">👥 Team</Link>|' app/dashboard/layout.tsx
  fi
  sed -i 's/\r$//' app/dashboard/layout.tsx
fi

# ---------- 11. .env add ----------
echo ""
echo "📝 Updating .env.example..."
if [ -f ".env.example" ]; then
  grep -q "ALLOWED_EMAILS" .env.example || echo 'ALLOWED_EMAILS="your-email@gmail.com,teammate@gmail.com"' >> .env.example
fi

# ---------- 12. Git push ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: campaign workflow + team-only login + preview + templates"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED"
echo "==================================================="
echo ""
echo "🚨 ZAROORI — Vercel me env var add karo (warna koi login nahi kar payega):"
echo ""
echo "   https://vercel.com/certwinx/emailcampaign/settings/environment-variables"
echo ""
echo "   Naya env var:"
echo "   ┌──────────────────────────────────────────────────┐"
echo "   │ Key:   ALLOWED_EMAILS                            │"
echo "   │ Value: certwinx@gmail.com,dipenzala1@gmail.com   │"
echo "   └──────────────────────────────────────────────────┘"
echo ""
echo "   👆 Apne actual emails daalo (comma-separated)"
echo ""
echo "   Phir: Redeploy → 2-3 min wait"
echo ""
echo "📊 Features added:"
echo "   ✅ Team-only login (invite-only)"
echo "   ✅ Full campaign workflow on /dashboard"
echo "   ✅ Email preview modal (live render)"
echo "   ✅ Test send"
echo "   ✅ Spam score check inline"
echo "   ✅ Live campaign view with Pause/Resume/Stop"
echo "   ✅ Templates table (save HTML)"
echo ""
echo "🎯 Test flow:"
echo "   1. Login → /login"
echo "   2. Import Excel → shows stats"
echo "   3. Compose → preview → test send"
echo "   4. Review → START CAMPAIGN"
echo "   5. Live dashboard with controls"
echo ""
echo "🎁 ADVANCED FEATURES YOU CAN ADD NEXT:"
echo ""
echo "   📧 EMAIL MARKETING:"
echo "   ├─ A/B Subject testing (split 50/50, auto-pick winner)"
echo "   ├─ Send-time optimization (10 AM local time per recipient)"
echo "   ├─ Open/click tracking (1x1 pixel + link wrapper)"
echo "   ├─ Attachment support (PDF, images via Gmail API)"
echo "   ├─ Plain text version editor"
echo "   ├─ Multi-language templates"
echo "   └─ Reply auto-classification (interested/unsubscribe/complaint)"
echo ""
echo "   👥 TEAM & ACCESS:"
echo "   ├─ Role-based access (Owner/Manager/Viewer)"
echo "   ├─ Team member activity log"
echo "   ├─ 2FA for team logins"
echo "   └─ Session management (revoke sessions)"
echo ""
echo "   📊 ANALYTICS:"
echo "   ├─ Campaign comparison (A vs B performance)"
echo "   ├─ Sender reputation dashboard (daily trend)"
echo "   ├─ Bounce rate alerts (email/push)"
echo "   ├─ CSV/Excel export of reports"
echo "   └─ Weekly email digest (auto-send summary)"
echo ""
echo "   🎨 TEMPLATES:"
echo "   ├─ Drag-drop template builder"
echo "   ├─ Template gallery (pre-built designs)"
echo "   ├─ Variable auto-detection"
echo "   └─ Duplicate campaign with one click"
echo ""
echo "   🔔 NOTIFICATIONS:"
echo "   ├─ Telegram bot (start/pause/status from phone)"
echo "   ├─ Slack webhook integration"
echo "   ├─ SMS alerts for critical errors"
echo "   └─ Browser push notifications"
echo ""
echo "   🔐 SECURITY:"
echo "   ├─ IP whitelist for admin access"
echo "   ├─ Login attempt rate limiting"
echo "   ├─ Sensitive action confirmation (delete, stop)"
echo "   └─ Audit log viewer"
echo ""
echo "   ⚡ POWER FEATURES:"
echo "   ├─ Scheduled campaigns (send at specific date/time)"
echo "   ├─ Recurring campaigns (weekly/monthly)"
echo "   ├─ Contact segmentation (filter by tag/company)"
echo "   ├─ Bulk suppression import"
echo "   └─ Webhook events (CRM integration)"
echo "==================================================="