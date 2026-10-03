'use client';
import { useEffect, useState } from 'react';

export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);

  const load = () => fetch('/api/senders').then(r => r.json()).then(setList);
  useEffect(() => { load(); }, []);

  const connect = () => {
    if (!email) return;
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email);
  };

  const disconnect = async (id: string, email: string) => {
    if (!confirm(`Disconnect ${email}?\n\nYe account future campaigns me use nahi hoga.`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/disconnect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      if (!r.ok) throw new Error('Failed');
      setMsg(`✅ Disconnected ${email}`);
      await load();
    } catch (e: any) {
      setMsg('❌ ' + e.message);
    }
    setBusy(false);
  };

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>

      {msg && <div className="card text-sm">{msg}</div>}

      {/* Connect */}
      <div className="card">
        <h2 className="font-semibold mb-2">Connect Gmail / Workspace</h2>
        <div className="flex gap-3 flex-wrap">
          <input
            className="input max-w-xs"
            placeholder="sales01@company.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email}>
            Connect Google
          </button>
        </div>
        <p className="text-xs text-slate-400 mt-2">
          OAuth only. Never share Gmail password. Permission: "Send email on your behalf" must be allowed.
        </p>
      </div>

      {/* Senders list */}
      <div className="card !p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr>
              <th className="p-3">Email</th>
              <th className="p-3">Name</th>
              <th className="p-3">Status</th>
              <th className="p-3">Sent Today</th>
              <th className="p-3">Last Success</th>
              <th className="p-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {list.map(s => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3">{s.email}</td>
                <td className="p-3">{s.displayName}</td>
                <td className="p-3">
                  <span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>
                    {s.status}
                  </span>
                </td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3 text-xs text-slate-500">
                  {s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}
                </td>
                <td className="p-3 text-right">
                  <button
                    onClick={() => disconnect(s.id, s.email)}
                    disabled={busy}
                    className="text-xs px-3 py-1.5 rounded-lg bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20 transition disabled:opacity-50"
                  >
                    Disconnect
                  </button>
                </td>
              </tr>
            ))}
            {list.length === 0 && (
              <tr>
                <td colSpan={6} className="p-8 text-center text-slate-500">
                  No senders connected. Add one above.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
