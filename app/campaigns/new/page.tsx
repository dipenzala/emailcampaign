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
  const [batchLimit, setBatchLimit] = useState(1);
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
