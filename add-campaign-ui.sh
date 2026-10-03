#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 📧 Add Campaign Creation UI"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }

# New campaign page
mkdir -p app/campaigns/new
cat > app/campaigns/new/page.tsx <<'EOF'
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

export default function NewCampaign() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('Campaign ' + new Date().toISOString().slice(0,10));
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>We have an update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [batchLimit, setBatchLimit] = useState(10);
  const [contacts, setContacts] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [spamReport, setSpamReport] = useState<any>(null);

  const uploadFile = async (f: File) => {
    setBusy(true); setMsg('');
    const fd = new FormData();
    fd.append('file', f);
    try {
      const r = await fetch('/api/contacts/upload', { method: 'POST', body: fd });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Upload failed');
      setContacts(j.contacts || []);
      setStats(j);
      setMsg(`✅ ${j.valid} valid emails loaded`);
    } catch (e: any) {
      setMsg('❌ ' + e.message);
    }
    setBusy(false);
  };

  const checkSpam = async () => {
    setBusy(true);
    const r = await fetch('/api/anti-spam/check', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subject, html }),
    });
    setSpamReport(await r.json());
    setBusy(false);
  };

  const launch = async () => {
    if (!contacts.length) { setMsg('❌ Contacts load karo pehle'); return; }
    if (!subject.trim()) { setMsg('❌ Subject daalo'); return; }
    setBusy(true); setMsg('');
    try {
      // 1. Create campaign
      const r = await fetch('/api/campaigns', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          emails: contacts.map((c: any) => c.email),
          batchLimit,
        }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(JSON.stringify(j.error));

      // 2. Start it
      const sr = await fetch(`/api/campaigns/${j.id}/start`, { method: 'POST' });
      const sj = await sr.json();
      if (!sr.ok) throw new Error(sj.error || 'Start failed');

      // 3. Go live
      router.push(`/campaigns/${j.id}`);
    } catch (e: any) {
      setMsg('❌ ' + e.message);
      setBusy(false);
    }
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-semibold tracking-tight">📧 New Campaign</h1>
        <Link href="/dashboard" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {msg && <div className="card text-sm">{msg}</div>}

      {/* Step indicator */}
      <div className="flex items-center gap-2">
        {[1,2,3].map(n => (
          <div key={n} className="flex items-center gap-2 flex-1">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm ${step >= n ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-500'}`}>{n}</div>
            <div className={`text-xs ${step >= n ? 'text-white' : 'text-slate-500'}`}>
              {n === 1 ? 'Contacts' : n === 2 ? 'Email' : 'Launch'}
            </div>
            {n < 3 && <div className={`flex-1 h-0.5 ${step > n ? 'bg-blue-600' : 'bg-slate-800'}`} />}
          </div>
        ))}
      </div>

      {/* STEP 1: Contacts */}
      {step === 1 && (
        <div className="card space-y-4">
          <h2 className="font-semibold">Step 1 — Load Contacts</h2>
          <input type="file" accept=".xlsx,.xls,.csv"
            onChange={e => e.target.files?.[0] && uploadFile(e.target.files[0])}
            className="input" disabled={busy} />

          {stats && (
            <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
              <Stat label="TOTAL" value={stats.totalRows} />
              <Stat label="VALID" value={stats.valid} accent="text-green-400" />
              <Stat label="INVALID" value={stats.invalid} accent="text-red-400" />
              <Stat label="DUPES" value={stats.duplicates} accent="text-yellow-400" />
              <Stat label="SUPPRESSED" value={stats.suppressed} accent="text-orange-400" />
            </div>
          )}

          {contacts.length > 0 && (
            <>
              <div className="text-sm text-green-400">✅ {contacts.length} valid emails ready</div>
              <div className="max-h-64 overflow-auto border border-slate-800 rounded">
                <table className="w-full text-xs">
                  <thead className="bg-slate-800 sticky top-0">
                    <tr><th className="text-left p-2">Email</th><th className="text-left p-2">Name</th></tr>
                  </thead>
                  <tbody>
                    {contacts.slice(0, 50).map((c, i) => (
                      <tr key={i} className="border-t border-slate-800">
                        <td className="p-2">{c.email}</td>
                        <td className="p-2">{c.name}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}

          <button onClick={() => setStep(2)} disabled={!contacts.length} className="btn btn-primary">
            Next → Email Content
          </button>
        </div>
      )}

      {/* STEP 2: HTML */}
      {step === 2 && (
        <div className="card space-y-4">
          <h2 className="font-semibold">Step 2 — Email Content</h2>
          <div>
            <label className="text-xs text-slate-400 block mb-1">Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>
          <div>
            <label className="text-xs text-slate-400 block mb-1">Subject</label>
            <input className="input" placeholder="Hello {{name}}, quick update" value={subject} onChange={e => setSubject(e.target.value)} />
          </div>
          <div>
            <label className="text-xs text-slate-400 block mb-1">HTML Body</label>
            <textarea className="input font-mono text-xs" rows={14} value={html} onChange={e => setHtml(e.target.value)} />
          </div>
          <div>
            <label className="text-xs text-slate-400 block mb-1">Batch limit per sender (emails)</label>
            <input type="number" className="input max-w-xs" value={batchLimit} onChange={e => setBatchLimit(parseInt(e.target.value) || 10)} />
            <p className="text-xs text-slate-500 mt-1">Har sender {batchLimit} emails bhejega, phir next sender.</p>
          </div>

          <div className="flex gap-2">
            <button onClick={checkSpam} disabled={busy} className="btn btn-ghost">🛡️ Spam Check</button>
            <button onClick={() => setStep(3)} className="btn btn-primary" disabled={!subject || !html}>Next → Review</button>
          </div>

          {spamReport && (
            <div className={`border rounded-lg p-4 ${spamReport.blocked ? 'border-red-500/30 bg-red-500/10' : spamReport.warning ? 'border-amber-500/30 bg-amber-500/10' : 'border-green-500/30 bg-green-500/10'}`}>
              <div className="font-semibold">Spam Score: {spamReport.score} ({spamReport.blocked ? '🚫 Blocked' : spamReport.warning ? '⚠️ Warning' : '✅ Safe'})</div>
              {spamReport.issues?.map((iss: any, i: number) => (
                <div key={i} className="text-xs mt-1">• {iss.message} (+{iss.points})</div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* STEP 3: Launch */}
      {step === 3 && (
        <div className="card space-y-4">
          <h2 className="font-semibold">Step 3 — Review & Launch</h2>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-slate-400 text-xs">Campaign</div>
              <div className="font-medium">{name}</div>
            </div>
            <div>
              <div className="text-slate-400 text-xs">Subject</div>
              <div className="font-medium">{subject}</div>
            </div>
            <div>
              <div className="text-slate-400 text-xs">Recipients</div>
              <div className="font-medium text-green-400">{contacts.length}</div>
            </div>
            <div>
              <div className="text-slate-400 text-xs">Batch limit</div>
              <div className="font-medium">{batchLimit} per sender</div>
            </div>
          </div>

          <div className="bg-amber-500/10 border border-amber-500/20 rounded-lg p-3 text-xs text-amber-300">
            ⚠️ {contacts.length} emails will be sent through {Math.ceil(contacts.length / batchLimit)} sender rotation cycle(s).
            <br />Warm-up limits apply per sender.
          </div>

          <div className="flex gap-2">
            <button onClick={() => setStep(2)} className="btn btn-ghost">← Back</button>
            <button onClick={launch} disabled={busy} className="btn btn-primary">
              {busy ? '🚀 Launching…' : '🚀 START CAMPAIGN'}
            </button>
          </div>
        </div>
      )}
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

# Add "New Campaign" button on dashboard
mkdir -p app/dashboard
if ! grep -q "New Campaign" app/dashboard/page.tsx 2>/dev/null; then
  # Rewrite dashboard page with CTA
  cat > app/dashboard/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function DashboardHome() {
  const [senders, setSenders] = useState<any[]>([]);
  useEffect(() => { fetch('/api/senders').then(r => r.ok ? r.json() : []).then(setSenders).catch(() => {}); }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Dashboard</h1>
          <p className="text-slate-400 mt-1">Import contacts, paste HTML, launch your campaign.</p>
        </div>
        <Link href="/campaigns/new" className="btn btn-primary text-base px-6 py-3">
          + New Campaign
        </Link>
      </div>

      {/* Big CTA */}
      <Link href="/campaigns/new" className="block tilt card !p-8 hover:shadow-2xl hover:shadow-violet-500/20 transition-all border-violet-500/30">
        <div className="flex items-center gap-6">
          <div className="text-6xl floaty">🚀</div>
          <div className="flex-1">
            <h2 className="text-2xl font-bold">Start a new campaign</h2>
            <p className="text-slate-400 mt-1">3 steps: upload contacts → paste HTML → launch</p>
          </div>
          <div className="text-3xl">→</div>
        </div>
      </Link>

      <div className="grid md:grid-cols-4 gap-4">
        <Link href="/senders" className="tilt card">
          <div className="text-3xl mb-2">🔐</div>
          <h3 className="font-semibold">Senders</h3>
          <p className="text-sm text-slate-400 mt-1">{senders.length} connected</p>
        </Link>
        <Link href="/senders/rotation" className="tilt card">
          <div className="text-3xl mb-2">🔄</div>
          <h3 className="font-semibold">Rotation</h3>
          <p className="text-sm text-slate-400 mt-1">Batch settings</p>
        </Link>
        <Link href="/anti-spam" className="tilt card">
          <div className="text-3xl mb-2">🛡️</div>
          <h3 className="font-semibold">Anti-Spam</h3>
          <p className="text-sm text-slate-400 mt-1">7-layer protection</p>
        </Link>
        <Link href="/history" className="tilt card">
          <div className="text-3xl mb-2">📊</div>
          <h3 className="font-semibold">History</h3>
          <p className="text-sm text-slate-400 mt-1">Past campaigns</p>
        </Link>
      </div>
    </div>
  );
}
EOF
  sed -i 's/\r$//' app/dashboard/page.tsx
fi

# Git push
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"
git add -A
git diff --cached --quiet || git commit -m "Feat: 3-step campaign creation UI + dashboard CTA"
git push -u origin main

echo ""
echo "==============================================="
echo " ✅ Campaign UI added — 2-3 min me deploy"
echo "==============================================="
echo ""
echo "🎯 Deploy ke baad:"
echo ""
echo "1. https://emailcampaign.vercel.app/dashboard"
echo "   → 'New Campaign' button dikhega"
echo ""
echo "2. Click karo → 3-step wizard:"
echo "   Step 1: Excel/CSV upload"
echo "   Step 2: Subject + HTML paste"
echo "   Step 3: Review → START"
echo ""
echo "3. Campaign live dashboard khulega"
echo "==============================================="