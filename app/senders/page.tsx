'use client';
import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { toast } from '@/components/Toast';

function SendersInner() {
  const params = useSearchParams();
  const [list, setList] = useState<any[]>([]);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [connecting, setConnecting] = useState(false);

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
    setConnecting(true);
    window.location.href = '/api/oauth/google/start';
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

  const connected = list.filter(s => s.status === 'CONNECTED').length;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
        <p className="text-sm text-slate-400 mt-1">
          {connected}/{list.length} connected · Auto-refresh 5s
        </p>
      </div>

      {/* BIG Connect Button */}
      <div className="card" style={{
        background: 'linear-gradient(135deg, rgba(139,92,246,0.15), rgba(236,72,153,0.1))',
        border: '1px solid rgba(139,92,246,0.3)',
      }}>
        <div className="flex flex-col items-center text-center gap-4 py-4">
          <div className="text-5xl floaty">🔐</div>
          <div>
            <h2 className="font-semibold text-lg mb-1">Connect Gmail Account</h2>
            <p className="text-xs text-slate-400">
              Click karo → Google account picker khulega → Allow karo
            </p>
          </div>
          <button
            onClick={connect}
            disabled={connecting}
            className="btn btn-primary text-base px-8 py-3.5"
            style={{ minWidth: 240 }}
          >
            {connecting ? (
              <>⏳ Opening Google...</>
            ) : (
              <>
                <svg width="20" height="20" viewBox="0 0 24 24" style={{ display: 'inline', marginRight: 8 }}>
                  <path fill="#fff" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                  <path fill="#fff" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path fill="#fff" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                  <path fill="#fff" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                </svg>
                Connect Google Account
              </>
            )}
          </button>
          <div className="text-xs text-slate-500 max-w-md">
            ⚠️ Google screen pe <b className="text-violet-300">"Send email on your behalf"</b> ko <b className="text-violet-300">ALLOW</b> karna zaroori hai
          </div>
        </div>
      </div>

      {/* Senders list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400 text-sm">Koi sender connect nahi hai</p>
          <p className="text-xs text-slate-500 mt-2">Upar button dabao</p>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="text-xs text-slate-500 uppercase tracking-wider font-semibold">
            Connected Senders ({list.length})
          </div>
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
                  <div className="font-semibold text-sm">{s.sentToday || 0}</div>
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

              <button
                onClick={() => disconnect(s.id, s.email)}
                disabled={busy}
                className="btn btn-danger w-full text-xs"
              >
                🚪 Disconnect
              </button>
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
