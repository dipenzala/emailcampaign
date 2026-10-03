'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
export default function AntiSpamPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [report, setReport] = useState<any>(null);
  const [subject, setSubject] = useState('Hello from our team');
  const [html, setHtml] = useState('<h1>Hi there</h1><p>We have an update.</p><p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>');
  const [checking, setChecking] = useState(false);
  useEffect(() => { fetch('/api/senders/rotation').then(r => r.json()).then(j => setSenders(j.senders ?? [])).catch(() => {}); }, []);
  const runCheck = async () => {
    setChecking(true);
    const r = await fetch('/api/anti-spam/check', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ subject, html, fromEmail: senders[0]?.email }) });
    setReport(await r.json());
    setChecking(false);
  };
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-semibold tracking-tight">🛡️ Anti-Spam</h1><p className="text-sm text-slate-400 mt-1">7-layer protection</p></div>
        <Link href="/senders" className="btn btn-ghost text-sm">← Senders</Link>
      </div>
      <div className="grid md:grid-cols-4 gap-3">
        {[['📊','Spam Checker','Pre-send analysis'],['🔥','Warm-up','5→10→25→50/day'],['🧹','Hygiene','Disposable filter'],['📉','Bounce','Auto-suppress']].map(([i,t,d]) => (
          <div key={t} className="card !p-4"><div className="text-2xl mb-1">{i}</div><div className="font-semibold text-sm">{t}</div><div className="text-xs text-slate-400 mt-1">{d}</div></div>
        ))}
      </div>
      <div className="card">
        <h2 className="font-semibold mb-3">📊 Content Spam Checker</h2>
        <p className="text-xs text-slate-400 mb-4">Score &lt;30 = safe, 30-49 = warning, 50+ = blocked.</p>
        <input className="input mb-2" value={subject} onChange={e => setSubject(e.target.value)} placeholder="Subject" />
        <textarea className="input font-mono text-xs mb-3" rows={8} value={html} onChange={e => setHtml(e.target.value)} />
        <button onClick={runCheck} disabled={checking} className="btn btn-primary">{checking ? 'Checking…' : 'Run Check'}</button>
        {report && (
          <div className="mt-4 border-t border-white/10 pt-4">
            <div className="flex items-center gap-4 mb-3">
              <div className={`text-4xl font-bold ${report.blocked ? 'text-red-400' : report.warning ? 'text-amber-400' : 'text-green-400'}`}>{report.score}</div>
              <div><div className="font-semibold">{report.blocked ? '🚫 BLOCKED' : report.warning ? '⚠️ Warning' : '✅ Safe'}</div></div>
            </div>
            {report.issues?.map((iss: any, i: number) => (
              <div key={i} className={`text-xs px-3 py-2 rounded-lg border mb-2 ${iss.severity === 'high' ? 'bg-red-500/10 border-red-500/20 text-red-300' : iss.severity === 'medium' ? 'bg-amber-500/10 border-amber-500/20 text-amber-300' : 'bg-slate-500/10 border-slate-500/20 text-slate-400'}`}>
                <b>{iss.category}:</b> {iss.message} <span className="opacity-60">(+{iss.points})</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
