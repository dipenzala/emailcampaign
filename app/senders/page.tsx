'use client';
import { useEffect, useState } from 'react';
export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  useEffect(()=>{ fetch('/api/senders').then(r=>r.json()).then(setList); }, []);
  const connect = () => { window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email); };
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">🔐 Manage Senders</h1>
      <div className="card">
        <h2 className="font-semibold mb-2">Connect a Gmail / Workspace account (OAuth)</h2>
        <div className="flex gap-3">
          <input className="input max-w-xs" placeholder="sales01@company.com" value={email} onChange={e=>setEmail(e.target.value)} />
          <button className="btn btn-primary" onClick={connect} disabled={!email}>CONNECT GOOGLE ACCOUNT</button>
        </div>
        <p className="text-xs text-slate-400 mt-2">Never share your Gmail password. Only OAuth is used. Tokens are encrypted at rest.</p>
      </div>
      <div className="card">
        <table className="w-full text-sm">
          <thead className="text-slate-400 text-left">
            <tr><th className="p-2">Email</th><th>Name</th><th>Status</th><th>Sent Today</th><th>Errors</th><th>Last Success</th></tr>
          </thead>
          <tbody>
            {list.map(s => (
              <tr key={s.id} className="border-t border-slate-800">
                <td className="p-2">{s.email}</td>
                <td>{s.displayName}</td>
                <td className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>{s.status}</td>
                <td>{s.sentToday}</td>
                <td>{s.errors}</td>
                <td>{s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}</td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={6} className="p-6 text-center text-slate-500">No senders connected yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
