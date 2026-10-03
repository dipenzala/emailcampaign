'use client';
import { useEffect, useState } from 'react';
import { toast } from '@/components/Toast';

export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/senders');
      const j = await r.json();
      setList(Array.isArray(j) ? j : []);
    } catch {}
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const connect = () => {
    if (!email) return;
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email);
  };

  const disconnect = async (id: string, em: string) => {
    if (!confirm(`Disconnect ${em}?`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/disconnect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      if (!r.ok) throw new Error('Failed');
      toast(`Disconnected ${em}`, 'success');
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>

      {/* Connect */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">Connect Gmail / Workspace</h2>
        <div className="flex flex-col sm:flex-row gap-2">
          <input
            className="input flex-1"
            placeholder="sales01@company.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
            type="email"
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email || busy}>
            Connect Google
          </button>
        </div>
        <p className="text-xs text-slate-400 mt-2">
          OAuth only. Permission: "Send email on your behalf" must be allowed.
        </p>
      </div>

      {/* Senders list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400">No senders connected</p>
        </div>
      ) : (
        <>
          {/* Desktop table */}
          <div className="hidden md:block card !p-0 overflow-hidden">
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
                    <td className="p-3">{s.displayName || '—'}</td>
                    <td className="p-3">
                      <span className={s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}>
                        ● {s.status}
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
                        className="text-xs px-3 py-1.5 rounded-lg bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20 transition"
                      >
                        Disconnect
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="md:hidden space-y-3">
            {list.map(s => (
              <div key={s.id} className="card !p-4">
                <div className="flex items-start justify-between gap-2 mb-3">
                  <div className="min-w-0 flex-1">
                    <div className="text-xs text-slate-500 truncate">{s.displayName || 'No name'}</div>
                    <div className="font-medium text-sm truncate">{s.email}</div>
                  </div>
                  <span className={`text-xs flex-shrink-0 px-2 py-1 rounded-lg ${s.status === 'CONNECTED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'}`}>
                    ● {s.status}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold text-sm">{s.sentToday}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">LAST SUCCESS</div>
                    <div className="font-semibold text-xs">
                      {s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleDateString() : '—'}
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => disconnect(s.id, s.email)}
                  disabled={busy}
                  className="btn btn-danger w-full text-xs"
                >
                  Disconnect
                </button>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
