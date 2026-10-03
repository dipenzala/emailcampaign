'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function AntiSpamPage() {
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [report, setReport] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [senders, setSenders] = useState<any[]>([]);
  const [fromEmail, setFromEmail] = useState('');

  useEffect(() => {
    fetch('/api/senders').then(r => r.json()).then(j => {
      const list = Array.isArray(j) ? j : [];
      setSenders(list);
      if (list[0]) setFromEmail(list[0].email);
    }).catch(() => {});
  }, []);

  const check = async () => {
    if (!subject.trim() || !html.trim()) {
      toast('Subject aur HTML daalo', 'error');
      return;
    }
    setBusy(true);
    try {
      const r = await fetch('/api/anti-spam/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, html, fromEmail }),
      });
      const j = await r.json();
      setReport(j);
      if (j.blocked) toast('🚫 Spam content detected', 'error');
      else if (j.warning) toast('⚠️ Warning — fix karo', 'info');
      else toast('✅ Safe to send', 'success');
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🛡️ Anti-Spam Checker</h1>
        <p className="text-sm text-slate-400 mt-1">
          Send se pehle check karo ki email spam me jayegi ya nahi
        </p>
      </div>

      {/* Live Sender Status */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">📊 Sender Health (Live)</h2>
        {senders.length === 0 ? (
          <p className="text-sm text-slate-400">
            Koi sender nahi. <Link href="/senders" className="text-violet-400 underline">Add karo →</Link>
          </p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {senders.map((s, i) => (
              <div key={i} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                <div className="text-xs text-slate-400 truncate mb-2">{s.email}</div>
                <div className="flex items-center justify-between">
                  <span className={`text-xs ${s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}`}>
                    ● {s.status}
                  </span>
                  <span className="text-xs text-slate-500">
                    Rep: {s.reputationScore ?? 100}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Spam Checker */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">🧪 Check Your Email</h2>

        <label className="text-xs text-slate-400 block mb-1">From Email</label>
        <input
          className="input mb-3 text-sm"
          placeholder="noreply@example.com"
          value={fromEmail}
          onChange={e => setFromEmail(e.target.value)}
        />

        <label className="text-xs text-slate-400 block mb-1">Subject</label>
        <input
          className="input mb-3 text-sm"
          placeholder="Subject line..."
          value={subject}
          onChange={e => setSubject(e.target.value)}
        />

        <label className="text-xs text-slate-400 block mb-1">HTML Body</label>
        <textarea
          className="input font-mono text-xs mb-3"
          rows={10}
          value={html}
          onChange={e => setHtml(e.target.value)}
        />

        <button onClick={check} disabled={busy} className="btn btn-primary w-full">
          {busy ? 'Checking...' : '🔍 Check Now'}
        </button>
      </div>

      {/* Report */}
      {report && (
        <div className={`card border-2 animate-in ${
          report.blocked ? 'border-red-500/50 bg-red-500/5'
          : report.warning ? 'border-amber-500/50 bg-amber-500/5'
          : 'border-emerald-500/50 bg-emerald-500/5'
        }`}>
          <div className="flex items-center gap-4 mb-4 flex-wrap">
            <div className={`text-4xl font-bold ${
              report.blocked ? 'text-red-400'
              : report.warning ? 'text-amber-400'
              : 'text-emerald-400'
            }`}>
              {report.score}
            </div>
            <div>
              <div className="text-lg font-semibold">
                {report.blocked ? '🚫 Blocked' : report.warning ? '⚠️ Warning' : '✅ Safe'}
              </div>
              <div className="text-xs text-slate-400">
                {report.blocked
                  ? 'Ye email spam me jayegi — fix karo'
                  : report.warning
                  ? 'Kuch issue hai — theek karo better result ke liye'
                  : 'Ye email spam me nahi jayegi'}
              </div>
            </div>
          </div>

          {report.issues?.length > 0 && (
            <div className="space-y-2">
              <div className="text-xs text-slate-400 uppercase font-semibold">Issues Found:</div>
              {report.issues.map((iss: any, i: number) => (
                <div key={i} className={`text-xs px-3 py-2 rounded-lg border ${
                  iss.severity === 'high'
                    ? 'bg-red-500/10 border-red-500/30 text-red-300'
                    : iss.severity === 'medium'
                    ? 'bg-amber-500/10 border-amber-500/30 text-amber-300'
                    : 'bg-slate-500/10 border-slate-500/30 text-slate-400'
                }`}>
                  <div className="flex items-center justify-between gap-2">
                    <span><b>{iss.category}:</b> {iss.message}</span>
                    <span className="text-[10px] opacity-60 flex-shrink-0">+{iss.points}</span>
                  </div>
                </div>
              ))}
            </div>
          )}

          {report.issues?.length === 0 && (
            <div className="text-sm text-emerald-400 text-center py-4">
              ✅ Koi issue nahi mila — email ready hai!
            </div>
          )}
        </div>
      )}

      {/* Tips */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">💡 Spam Se Bachne Ke Tips</h2>
        <ul className="text-sm text-slate-400 space-y-2 list-disc list-inside">
          <li>Subject me ALL CAPS na rakho</li>
          <li>Zyada `!!!` ya `$$$` mat daalo</li>
          <li>Unsubscribe link zaroor rakho</li>
          <li>URL shorteners (bit.ly) avoid karo</li>
          <li>80% text aur 20% images rakho</li>
          <li>Sender warm-up enabled rakho (naya account)</li>
        </ul>
      </div>
    </div>
  );
}
