'use client';
import { useEffect, useState } from 'react';
export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [msg, setMsg] = useState('');
  const load = () => fetch('/api/senders').then(r => r.json()).then(setList);
  useEffect(() => { load(); }, []);
  const connect = () => { window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email); };
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
      {msg && <div className="card text-sm text-green-400">{msg}</div>}
      <div className="card">
        <h2 className="font-semibold mb-2">Connect Gmail / Workspace</h2>
        <div className="flex gap-3 flex-wrap">
          <input className="input max-w-xs" placeholder="sales01@company.com" value={email} onChange={e => setEmail(e.target.value)} />
          <button className="btn btn-primary" onClick={connect} disabled={!email}>Connect Google</button>
        </div>
      </div>
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">Email</th><th className="p-3">Status</th><th className="p-3">Sent Today</th><th className="p-3">Last Success</th></tr>
          </thead>
          <tbody>
            {list.map(s => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3">{s.email}</td>
                <td className="p-3"><span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>{s.status}</span></td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3 text-xs text-slate-500">{s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}</td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={4} className="p-8 text-center text-slate-500">No senders.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
