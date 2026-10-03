'use client';
import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { toast } from '@/components/Toast';

function SendersInner() {
  const params = useSearchParams();
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/senders');
      const j = await r.json();
      setList(Array.isArray(j) ? j : []);
    } catch {}
    setLoading(false);
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  useEffect(() => {
    const connected = params.get('connected');
    if (connected) {
      toast(`✅ Connected ${connected}`, 'success');
      window.history.replaceState({}, '', '/senders');
    }
  }, [params]);

  const connect = () => {
    if (!email || !email.includes('@')) {
      toast('Valid email daalo', 'error');
      return;
    }
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

  const reconnect = async (em: string) => {
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(em);
  };

  const connected = list.filter(s => s.status === 'CONNECTED').length;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
        <p className="text-sm text-slate-400 mt-1">
          {connected}/{list.length} connected · Auto-refresh 5s
        </p>
      </div>

      {/* Connect */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">➕ Connect Gmail Account</h2>
        <div className="flex flex-col sm:flex-row gap-2">
          <input
            className="input flex-1"
            placeholder="yourname@gmail.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
            type="email"
            onKeyDown={e => e.key === 'Enter' && connect()}
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email || busy}>
            Connect Google
          </button>
        </div>
        <div className="mt-3 p-3 rounded-lg bg-blue-500/10 border border-blue-500/20 text-xs text-blue-300">
          ⚠️ Google screen pe <b>"Send email on your behalf"</b> ko <b>ALLOW</b> karo — warna emails nahi jayengi.
        </div>
      </div>

      {/* Senders list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400 text-sm">Koi sender connect nahi hai</p>
        </div>
      ) : (
        <div className="space-y-3">
          {list.map(s => (
            <div key={s.id} className="card !p-4">
              <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
                <div className="min-w-0 flex-1">
                  <div className="font-medium text-sm truncate">{s.email}</div>
                  {s.displayName && <div className="text-xs text-slate-500 truncate">{s.displayName}</div>}
                </div>
                <span className={`text-xs px-2.5 py-1 rounded-lg font-medium flex-shrink-0 ${
                  s.status === 'CONNECTED'
                    ? 'bg-emerald-500/20 text-emerald-400'
                    : 'bg-red-500/20 text-red-400'
                }`}>
                  ● {s.status}
                </span>
              </div>

              <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                <div className="bg-white/5 rounded-lg p-2">
                  <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                  <div className="font-semibold text-sm">{s.sentToday}</div>
                </div>
                <div className="bg-white/5 rounded-lg p-2">
                  <div className="text-slate-500 text-[10px]">LIMIT</div>
                  <div className="font-semibold text-sm">{s.dailyLimit || 500}</div>
                </div>
                <div className="bg-white/5 rounded-lg p-2">
                  <div className="text-slate-500 text-[10px]">REP</div>
                  <div className="font-semibold text-sm">{s.reputationScore ?? 100}</div>
                </div>
              </div>

              <div className="flex gap-2">
                <button
                  onClick={() => reconnect(s.email)}
                  disabled={busy}
                  className="btn btn-ghost flex-1 text-xs"
                >
                  🔄 Reconnect
                </button>
                <button
                  onClick={() => disconnect(s.id, s.email)}
                  disabled={busy}
                  className="btn btn-danger flex-1 text-xs"
                >
                  Disconnect
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function SendersPage() {
  return (
    <Suspense fallback={<div className="card text-center py-8 text-slate-500">Loading...</div>}>
      <SendersInner />
    </Suspense>
  );
}
