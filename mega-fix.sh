#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎯 MEGA FIX — Clear + Auth + Live + Preview"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. SIMPLE AUTH LIB
# ==========================================
echo "🔐 [1/8] Creating auth lib..."
mkdir -p lib

cat > lib/simple-auth.ts <<'EOF'
import crypto from 'crypto';

const PASSWORD = 'DIPEN@3899';
const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
const COOKIE_NAME = 'ec_auth';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

export function checkPassword(input: string): boolean {
  return input === PASSWORD;
}

export function createAuthToken(): string {
  const payload = Buffer.from(JSON.stringify({ admin: true, ts: Date.now() })).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function verifyAuthToken(token?: string): boolean {
  if (!token) return false;
  const [payload, sig] = token.split('.');
  if (!payload || !sig) return false;
  const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  if (sig !== expected) return false;
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return data.admin === true;
  } catch { return false; }
}

export const AUTH_COOKIE = COOKIE_NAME;
export const AUTH_COOKIE_MAX_AGE = COOKIE_MAX_AGE;
EOF
sed -i 's/\r$//' lib/simple-auth.ts
echo "   ✅"

# ==========================================
# 2. LOGIN / LOGOUT / ME APIs
# ==========================================
echo "🔐 [2/8] Creating auth APIs..."

mkdir -p app/api/auth/simple-login app/api/auth/simple-logout app/api/auth/simple-me

cat > app/api/auth/simple-login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { checkPassword, createAuthToken, AUTH_COOKIE, AUTH_COOKIE_MAX_AGE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { password } = await req.json();
    if (!password) return NextResponse.json({ error: 'Password required' }, { status: 400 });
    if (!checkPassword(password)) return NextResponse.json({ error: 'Wrong password' }, { status: 401 });
    const token = createAuthToken();
    const res = NextResponse.json({ ok: true });
    res.cookies.set(AUTH_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: AUTH_COOKIE_MAX_AGE,
    });
    return res;
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'Login failed' }, { status: 500 });
  }
}
EOF

cat > app/api/auth/simple-logout/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(AUTH_COOKIE, '', { path: '/', maxAge: 0 });
  return res;
}
EOF

cat > app/api/auth/simple-me/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const token = cookies().get(AUTH_COOKIE)?.value;
  const ok = verifyAuthToken(token);
  if (!ok) return NextResponse.json({ auth: false }, { status: 401 });
  return NextResponse.json({ auth: true });
}
EOF
sed -i 's/\r$//' app/api/auth/simple-login/route.ts app/api/auth/simple-logout/route.ts app/api/auth/simple-me/route.ts
echo "   ✅"

# ==========================================
# 3. PASSWORD-ONLY LOGIN PAGE
# ==========================================
echo "🔐 [3/8] Creating password login page..."

mkdir -p app/login

cat > app/login/page.tsx <<'EOF'
'use client';
import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard/live';
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(''); setBusy(true);
    try {
      const r = await fetch('/api/auth/simple-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next);
      router.refresh();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />
      <div className="relative z-10 w-full max-w-md">
        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty flex items-center justify-center text-2xl">🔒</div>
            <h1 className="text-2xl font-semibold tracking-tight">EmailCampaign</h1>
            <p className="text-sm text-slate-400 mt-2">Enter password to continue</p>
          </div>
          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Password</label>
              <input
                type="password"
                required
                autoFocus
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="••••••••"
                className="input text-center text-lg tracking-widest"
                autoComplete="current-password"
              />
            </div>
            {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5 text-center">❌ {err}</div>}
            <button type="submit" disabled={busy || !password} className="btn btn-primary w-full py-3">
              {busy ? 'Verifying…' : '🔓 Unlock'}
            </button>
          </form>
          <div className="mt-6 text-xs text-slate-500 text-center">Authorized access only</div>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
EOF
sed -i 's/\r$//' app/login/page.tsx
echo "   ✅"

# ==========================================
# 4. LIVE STATS API
# ==========================================
echo "📊 [4/8] Creating /api/live/stats..."

mkdir -p app/api/live/stats

cat > app/api/live/stats/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
    }

    const groups = await prisma.campaignRecipient.groupBy({
      by: ['status'],
      _count: { _all: true },
    });

    const byStatus: Record<string, number> = {};
    groups.forEach(g => { byStatus[g.status] = g._count._all; });

    const queued = byStatus.QUEUED ?? 0;
    const processing = byStatus.PROCESSING ?? 0;
    const sent = byStatus.SENT ?? 0;
    const delivered = byStatus.DELIVERED ?? 0;
    const failed = byStatus.FAILED ?? 0;
    const bounced = byStatus.BOUNCED ?? 0;
    const suppressed = byStatus.SUPPRESSED ?? 0;
    const pending = queued + processing;
    const total = queued + processing + sent + delivered + failed + bounced + suppressed;

    const senders = await prisma.senderAccount.findMany({
      orderBy: [{ status: 'asc' }, { sentToday: 'asc' }],
      select: {
        email: true, sentToday: true, dailyLimit: true, batchCount: true,
        status: true, isActive: true, reputationScore: true,
      },
    });

    const campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });

    // Recent activity
    const recent = await prisma.campaignRecipient.findMany({
      take: 15,
      orderBy: { sentAt: 'desc' },
      where: { sentAt: { not: null } },
      include: { contact: true },
    });

    const activity = recent.map(r =>
      `[${r.sentAt ? new Date(r.sentAt).toLocaleTimeString() : '--'}] ✅ ${r.contact.email}`
    );

    return NextResponse.json({
      ok: true,
      stats: { total, sent, delivered, failed, bounced, suppressed, pending, queued, processing },
      senders,
      campaign,
      activity,
      ts: Date.now(),
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/live/stats/route.ts
echo "   ✅"

# ==========================================
# 5. LIVE DASHBOARD PAGE
# ==========================================
echo "📊 [5/8] Creating live dashboard..."

mkdir -p app/dashboard/live

cat > app/dashboard/live/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function LiveDashboard() {
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [tick, setTick] = useState(0);

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats);
        setSenders(j.senders || []);
        setCampaign(j.campaign);
        setActivity(j.activity || []);
        setTick(t => t + 1);
      }
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 2000);
    return () => clearInterval(iv);
  }, []);

  const logout = async () => {
    await fetch('/api/auth/simple-logout', { method: 'POST' });
    window.location.href = '/login';
  };

  const progress = stats.total > 0 ? ((stats.total - stats.pending) / stats.total) * 100 : 0;

  return (
    <div className="min-h-screen bg-slate-950 text-white">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
            <span className="font-semibold tracking-tight text-sm">EmailCampaign</span>
          </div>
          <div className="flex items-center gap-1">
            <Link href="/dashboard/live" className="text-sm text-white px-3 py-1.5 rounded-lg bg-white/10">Live</Link>
            <Link href="/campaigns/new" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">+ New</Link>
            <Link href="/senders" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">Senders</Link>
            <Link href="/history" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">History</Link>
            <button onClick={logout} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">Logout</button>
          </div>
        </div>
      </nav>

      <main className="max-w-6xl mx-auto px-6 py-8 space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-3xl font-semibold tracking-tight flex items-center gap-3">
              🔴 Live Dashboard
              <span className="text-xs px-2 py-1 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 animate-pulse">LIVE</span>
            </h1>
            <p className="text-sm text-slate-400 mt-1">
              Auto-refresh 2s · Last: {new Date().toLocaleTimeString()} · Tick #{tick}
            </p>
          </div>
          <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New Campaign</Link>
        </div>

        {/* Big KPIs */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <KPI label="TOTAL" value={stats.total} color="text-white" big />
          <KPI label="SENT" value={stats.sent} color="text-blue-400" big />
          <KPI label="PENDING" value={stats.pending} color="text-amber-400" big />
          <KPI label="FAILED" value={stats.failed} color="text-red-400" big />
        </div>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <KPI label="QUEUED" value={stats.queued} color="text-yellow-400" />
          <KPI label="PROCESSING" value={stats.processing} color="text-purple-400" />
          <KPI label="DELIVERED" value={stats.delivered} color="text-emerald-400" />
          <KPI label="BOUNCED" value={stats.bounced} color="text-orange-400" />
          <KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" />
        </div>

        {/* Progress */}
        <div className="card">
          <div className="flex justify-between text-sm mb-2">
            <span className="font-medium">Overall Progress</span>
            <span className="text-lg font-bold">{progress.toFixed(1)}%</span>
          </div>
          <div className="w-full h-4 bg-slate-800 rounded-full overflow-hidden">
            <div className="h-full bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 transition-all duration-500 rounded-full"
              style={{ width: progress + '%' }} />
          </div>
        </div>

        {/* Senders */}
        <div className="card">
          <h2 className="font-semibold mb-3">👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)</h2>
          {senders.length === 0 ? (
            <p className="text-sm text-slate-400">No senders connected</p>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-3">
              {senders.map((s, i) => {
                const usage = s.dailyLimit > 0 ? (s.sentToday / s.dailyLimit) * 100 : 0;
                return (
                  <div key={i} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                    <div className="text-xs text-slate-400 truncate">{s.email}</div>
                    <div className="flex items-center justify-between mt-2">
                      <span className={`text-xs ${s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}`}>● {s.status}</span>
                      <span className="text-xs text-slate-500">{s.sentToday}/{s.dailyLimit}</span>
                    </div>
                    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mt-2">
                      <div className={`h-full ${usage >= 100 ? 'bg-red-500' : usage >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}`}
                        style={{ width: Math.min(100, usage) + '%' }} />
                    </div>
                    <div className="flex justify-between mt-1 text-[10px] text-slate-500">
                      <span>Batch: {s.batchCount}</span>
                      <span>Rep: {s.reputationScore}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {campaign && (
          <div className="card border-emerald-500/30">
            <h2 className="font-semibold mb-3">📧 Latest Campaign
              <span className="ml-2 text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400">{campaign.status}</span>
            </h2>
            <div className="grid md:grid-cols-3 gap-3 text-sm">
              <div><div className="text-xs text-slate-500">Name</div><div className="font-medium">{campaign.name}</div></div>
              <div><div className="text-xs text-slate-500">Subject</div><div className="font-medium truncate">{campaign.subject}</div></div>
              <div><div className="text-xs text-slate-500">Created</div><div className="font-medium">{new Date(campaign.createdAt).toLocaleString()}</div></div>
            </div>
          </div>
        )}

        {/* Activity */}
        <div className="card">
          <h2 className="font-semibold mb-3">📜 Live Activity</h2>
          <div className="bg-black border border-slate-800 rounded-lg p-4 max-h-64 overflow-auto font-mono text-xs">
            {activity.length === 0 ? <div className="text-slate-500">Waiting for activity...</div> :
              activity.map((l, i) => <div key={i} className="text-emerald-300 py-0.5">{l}</div>)}
          </div>
        </div>
      </main>
    </div>
  );
}

function KPI({ label, value, color, big = false }: { label: string; value: number; color: string; big?: boolean }) {
  return (
    <div className={`${big ? 'card !p-5' : 'bg-slate-950 border border-slate-800 rounded-lg p-3'}`}>
      <div className={`text-[10px] uppercase text-slate-500 tracking-wider`}>{label}</div>
      <div className={`${big ? 'text-4xl' : 'text-xl'} font-bold mt-1 ${color}`}>{(value || 0).toLocaleString()}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/live/page.tsx
echo "   ✅"

# ==========================================
# 6. CAMPAIGN WIZARD WITH PREVIEW
# ==========================================
echo "📧 [6/8] Creating campaign wizard with preview..."

mkdir -p app/campaigns/new

cat > app/campaigns/new/page.tsx <<'EOF'
'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

type Contact = { email: string; name?: string; company?: string };

export default function NewCampaign() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('Campaign ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [batchLimit, setBatchLimit] = useState(10);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [spamReport, setSpamReport] = useState<any>(null);
  const [manualEmails, setManualEmails] = useState('');

  useEffect(() => {
    const s = localStorage.getItem('ec_manual');
    if (s) setManualEmails(s);
  }, []);
  useEffect(() => { localStorage.setItem('ec_manual', manualEmails); }, [manualEmails]);

  const uploadFile = async (f: File) => {
    setBusy(true); setMsg('');
    const fd = new FormData(); fd.append('file', f);
    try {
      const r = await fetch('/api/contacts/upload', { method: 'POST', body: fd });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Upload failed');
      setContacts(j.contacts || []); setStats(j);
      setMsg(`✅ ${j.valid} valid emails loaded`);
    } catch (e: any) { setMsg('❌ ' + e.message); }
    setBusy(false);
  };

  const parseManual = () => {
    const lines = manualEmails.split(/[\n,;]+/).map(l => l.trim()).filter(Boolean);
    const valid: Contact[] = []; const invalid: string[] = [];
    const seen = new Set(contacts.map(c => c.email.toLowerCase()));
    for (const line of lines) {
      const parts = line.split(/[,|\t]/).map(p => p.trim());
      const email = parts[0]?.toLowerCase(); if (!email) continue;
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { invalid.push(email); continue; }
      if (seen.has(email)) continue;
      seen.add(email);
      valid.push({ email, name: parts[1] || '', company: parts[2] || '' });
    }
    if (valid.length === 0) { setMsg(invalid.length ? `❌ All ${invalid.length} invalid` : '❌ No new emails'); return; }
    setContacts([...contacts, ...valid]);
    setMsg(`✅ Added ${valid.length} emails${invalid.length ? ` (${invalid.length} invalid)` : ''}`);
  };

  const checkSpam = async () => {
    setBusy(true);
    const r = await fetch('/api/anti-spam/check', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subject, html }),
    });
    setSpamReport(await r.json()); setBusy(false);
  };

  const launch = async () => {
    if (!contacts.length) { setMsg('❌ Add contacts'); return; }
    if (!subject.trim()) { setMsg('❌ Add subject'); return; }
    setBusy(true); setMsg('');
    try {
      const r = await fetch('/api/campaigns', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, subject, html, emails: contacts.map(c => c.email), batchLimit }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error?.message || JSON.stringify(j.error) || 'Create failed');
      const sr = await fetch(`/api/campaigns/${j.id}/start`, { method: 'POST' });
      const sj = await sr.json();
      if (!sr.ok) throw new Error(sj.error || 'Start failed');
      router.push('/dashboard/live');
    } catch (e: any) { setMsg('❌ ' + e.message); setBusy(false); }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-white p-6">
      <div className="space-y-6 max-w-4xl mx-auto">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-semibold tracking-tight">📧 New Campaign</h1>
          <Link href="/dashboard/live" className="btn btn-ghost text-sm">← Dashboard</Link>
        </div>

        {msg && <div className="card text-sm">{msg}</div>}

        <div className="flex items-center gap-2">
          {[1,2,3,4].map(n => (
            <div key={n} className="flex items-center gap-2 flex-1">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm ${step >= n ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-500'}`}>{n}</div>
              <div className={`text-xs ${step >= n ? 'text-white' : 'text-slate-500'}`}>
                {n === 1 ? 'Contacts' : n === 2 ? 'Email' : n === 3 ? 'Preview' : 'Launch'}
              </div>
              {n < 4 && <div className={`flex-1 h-0.5 ${step > n ? 'bg-blue-600' : 'bg-slate-800'}`} />}
            </div>
          ))}
        </div>

        {step === 1 && (
          <div className="card space-y-5">
            <h2 className="font-semibold">Step 1 — Add Contacts</h2>
            <div>
              <label className="text-xs text-slate-400 block mb-2">📁 Upload Excel / CSV</label>
              <input type="file" accept=".xlsx,.xls,.csv" onChange={e => e.target.files?.[0] && uploadFile(e.target.files[0])} className="input" disabled={busy} />
            </div>
            <div className="border-t border-slate-800 pt-5">
              <label className="text-xs text-slate-400 block mb-2">✍️ Manual Entry (one email per line)</label>
              <textarea className="input font-mono text-xs" rows={6} placeholder="email  OR  email,name  OR  email,name,company" value={manualEmails} onChange={e => setManualEmails(e.target.value)} />
              <button onClick={parseManual} disabled={!manualEmails.trim() || busy} className="btn btn-ghost mt-2">➕ Add Manual Emails</button>
            </div>
            {stats && (
              <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm border-t border-slate-800 pt-5">
                <Stat label="TOTAL" value={stats.totalRows} />
                <Stat label="VALID" value={stats.valid} accent="text-green-400" />
                <Stat label="INVALID" value={stats.invalid} accent="text-red-400" />
                <Stat label="DUPES" value={stats.duplicates} accent="text-yellow-400" />
                <Stat label="SUPPRESSED" value={stats.suppressed} accent="text-orange-400" />
              </div>
            )}
            {contacts.length > 0 && (
              <div className="border-t border-slate-800 pt-5">
                <div className="text-sm text-green-400 mb-3">
                  ✅ {contacts.length} contacts ready
                  <button onClick={() => { setContacts([]); setStats(null); }} className="text-xs text-red-400 ml-3 hover:underline">Clear</button>
                </div>
                <div className="max-h-48 overflow-auto border border-slate-800 rounded">
                  <table className="w-full text-xs">
                    <thead className="bg-slate-800 sticky top-0"><tr><th className="text-left p-2 w-8">#</th><th className="text-left p-2">Email</th><th className="text-left p-2">Name</th><th className="w-8"></th></tr></thead>
                    <tbody>
                      {contacts.map((c, i) => (
                        <tr key={i} className="border-t border-slate-800">
                          <td className="p-2 text-slate-500">{i+1}</td>
                          <td className="p-2">{c.email}</td>
                          <td className="p-2 text-slate-400">{c.name}</td>
                          <td className="p-2"><button onClick={() => setContacts(contacts.filter((_, j) => j !== i))} className="text-red-400">✕</button></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
            <button onClick={() => setStep(2)} disabled={!contacts.length} className="btn btn-primary">Next → Email</button>
          </div>
        )}

        {step === 2 && (
          <div className="card space-y-4">
            <h2 className="font-semibold">Step 2 — Email Content</h2>
            <div><label className="text-xs text-slate-400 block mb-1">Campaign Name</label><input className="input" value={name} onChange={e => setName(e.target.value)} /></div>
            <div><label className="text-xs text-slate-400 block mb-1">Subject</label><input className="input" value={subject} onChange={e => setSubject(e.target.value)} /></div>
            <div><label className="text-xs text-slate-400 block mb-1">HTML Body</label><textarea className="input font-mono text-xs" rows={12} value={html} onChange={e => setHtml(e.target.value)} /></div>
            <div><label className="text-xs text-slate-400 block mb-1">Batch limit</label><input type="number" className="input max-w-xs" value={batchLimit} onChange={e => setBatchLimit(parseInt(e.target.value) || 10)} /></div>
            <div className="flex gap-2 flex-wrap">
              <button onClick={checkSpam} disabled={busy} className="btn btn-ghost">🛡️ Spam Check</button>
              <button onClick={() => setStep(1)} className="btn btn-ghost">← Back</button>
              <button onClick={() => setStep(3)} className="btn btn-primary" disabled={!subject || !html}>Next → Preview</button>
            </div>
            {spamReport && (
              <div className={`border rounded-lg p-4 ${spamReport.blocked ? 'border-red-500/30 bg-red-500/10' : spamReport.warning ? 'border-amber-500/30 bg-amber-500/10' : 'border-green-500/30 bg-green-500/10'}`}>
                <div className="font-semibold">Spam Score: {spamReport.score} ({spamReport.blocked ? '🚫 Blocked' : spamReport.warning ? '⚠️ Warning' : '✅ Safe'})</div>
                {spamReport.issues?.map((iss: any, i: number) => <div key={i} className="text-xs mt-1">• {iss.message} (+{iss.points})</div>)}
              </div>
            )}
          </div>
        )}

        {step === 3 && (
          <div className="card space-y-4">
            <h2 className="font-semibold">👁️ Step 3 — Preview Recipients</h2>
            <p className="text-sm text-slate-400">Ye list check karo — sirf inhi emails ko message jayega.</p>
            <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4 grid grid-cols-3 gap-4 text-sm">
              <div><div className="text-xs text-slate-400">Total</div><div className="text-2xl font-bold text-blue-400">{contacts.length}</div></div>
              <div><div className="text-xs text-slate-400">Batch</div><div className="text-2xl font-bold">{batchLimit}</div></div>
              <div><div className="text-xs text-slate-400">Cycles</div><div className="text-2xl font-bold">{Math.ceil(contacts.length / batchLimit)}</div></div>
            </div>
            <div className="border border-slate-800 rounded-lg overflow-hidden">
              <div className="bg-slate-900 px-4 py-2 text-xs text-slate-400 border-b border-slate-800">Email List ({contacts.length})</div>
              <div className="max-h-96 overflow-auto">
                <table className="w-full text-xs">
                  <thead className="bg-slate-900 sticky top-0"><tr><th className="text-left p-2 w-10">#</th><th className="text-left p-2">Email</th><th className="text-left p-2">Name</th><th className="text-left p-2">Company</th></tr></thead>
                  <tbody>
                    {contacts.map((c, i) => (
                      <tr key={i} className="border-t border-slate-800 hover:bg-white/5">
                        <td className="p-2 text-slate-500">{i+1}</td>
                        <td className="p-2 font-mono">{c.email}</td>
                        <td className="p-2 text-slate-400">{c.name || '—'}</td>
                        <td className="p-2 text-slate-400">{c.company || '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="flex gap-2">
              <button onClick={() => setStep(2)} className="btn btn-ghost">← Back</button>
              <button onClick={() => setStep(4)} className="btn btn-primary">Next → Launch</button>
            </div>
          </div>
        )}

        {step === 4 && (
          <div className="card space-y-4">
            <h2 className="font-semibold">🚀 Step 4 — Final Review</h2>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div><div className="text-slate-400 text-xs">Campaign</div><div className="font-medium">{name}</div></div>
              <div><div className="text-slate-400 text-xs">Subject</div><div className="font-medium">{subject}</div></div>
              <div><div className="text-slate-400 text-xs">Recipients</div><div className="font-medium text-green-400">{contacts.length}</div></div>
              <div><div className="text-slate-400 text-xs">Batch Limit</div><div className="font-medium">{batchLimit}</div></div>
            </div>
            <div className="bg-amber-500/10 border border-amber-500/20 rounded-lg p-3 text-xs text-amber-300">
              ⚠️ Launch ke baad turant Live Dashboard pe redirect hoga.
            </div>
            <div className="flex gap-2">
              <button onClick={() => setStep(3)} className="btn btn-ghost">← Back</button>
              <button onClick={launch} disabled={busy} className="btn btn-primary">
                {busy ? '🚀 Launching…' : `🚀 Launch — ${contacts.length} emails`}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value, accent = '' }: { label: string; value: number; accent?: string }) {
  return (
    <div className="bg-slate-950 border border-slate-800 rounded-lg p-3">
      <div className="text-[10px] uppercase text-slate-400">{label}</div>
      <div className={`text-xl font-bold ${accent}`}>{value?.toLocaleString() ?? 0}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/campaigns/new/page.tsx
echo "   ✅"

# ==========================================
# 7. MIDDLEWARE
# ==========================================
echo "🛡️  [7/8] Updating middleware..."

cat > middleware.ts <<'EOF'
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const AUTH_COOKIE = 'ec_auth';

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Public routes
  if (pathname === '/login' || pathname === '/') {
    return NextResponse.next();
  }

  // Protected routes
  const protectedPrefixes = ['/dashboard', '/senders', '/history', '/campaigns', '/anti-spam', '/worker'];
  const isProtected = protectedPrefixes.some(p => pathname.startsWith(p));

  if (!isProtected) return NextResponse.next();

  const token = req.cookies.get(AUTH_COOKIE)?.value;
  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/worker/:path*',
    '/login',
  ],
};
EOF
sed -i 's/\r$//' middleware.ts
echo "   ✅"

# ==========================================
# 8. CLEAR DATA + GIT PUSH
# ==========================================
echo ""
echo "🧹 [8/8] Clearing data + git push..."

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
  echo "   ✅ .env loaded"
fi

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  console.log("");
  console.log("   Resetting senders...");
  const senders = await p.senderAccount.findMany();
  for (const s of senders) {
    if (s.status === "CONNECTED" && s.refreshToken) {
      await p.senderAccount.update({
        where: { id: s.id },
        data: { warmupEnabled: false, dailyLimit: 500, batchCount: 0, sentToday: 0, isActive: true },
      });
    }
  }
  console.log("   ✅ " + senders.length + " senders reset");

  const r1 = await p.campaignRecipient.updateMany({
    where: { status: { in: ["FAILED", "PROCESSING", "BOUNCED"] } },
    data: { status: "QUEUED", attemptCount: 0, errorMessage: null, errorCode: null, failedAt: null, bounceType: null },
  });
  console.log("   ✅ " + r1.count + " recipients → QUEUED");

  const camps = await p.campaign.findMany({
    where: { status: { in: ["PAUSED", "DRAFT", "STOPPED"] }, recipients: { some: { status: "QUEUED" } } },
  });
  for (const c of camps) {
    await p.campaign.update({ where: { id: c.id }, data: { status: "RUNNING" } });
  }
  console.log("   ✅ " + camps.length + " campaigns → RUNNING");

  const queued = await p.campaignRecipient.count({ where: { status: "QUEUED" } });
  const activeSenders = await p.senderAccount.count({ where: { status: "CONNECTED" } });
  console.log("");
  console.log("   📊 QUEUED: " + queued + " | Active senders: " + activeSenders);
  await p.$disconnect();
})();
NODEEOF

echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: password auth + live dashboard + preview + auto-redirect"
git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ MEGA SCRIPT COMPLETE"
echo "==============================================="
echo ""
echo "🎯 2 min wait karo (Vercel deploy)"
echo ""
echo "🔐 LOGIN:"
echo "   https://emailcampaign-ten.vercel.app/login"
echo "   Password: DIPEN@3899"
echo ""
echo "🎯 AUTO-REDIRECT:"
echo "   Login ke baad → /dashboard/live"
echo ""
echo "📧 NEW CAMPAIGN:"
echo "   /campaigns/new → 4 steps → Launch → Live dashboard"
echo ""
echo "🛡️  SECURITY:"
echo "   • Sirf password auth (DIPEN@3899)"
echo "   • Har protected route behind middleware"
echo "   • 30 din session cookie"
echo "==============================================="