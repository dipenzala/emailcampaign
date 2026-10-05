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
    const c = params.get('connected');
    if (c) {
      toast(`✅ Connected ${c}`, 'success');
      window.history.replaceState({}, '', '/senders');
    }
  }, [params]);

  const connect = () => {
    if (!email || !email.includes('@')) { toast('Valid email daalo', 'error'); return; }
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

  const reconnect = (em: string) => {
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(em);
  };

  const connected = list.filter(s => s.status === 'CONNECTED').length;
  const totalCapacity = connected * 350;
  const totalUsed = list.reduce((sum, s) => sum + (s.sentToday || 0), 0);

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
        <p className="text-sm" style={{ color: 'var(--fg-muted)', marginTop: 4 }}>
          {connected}/{list.length} connected · Auto-refresh 5s
        </p>
      </div>

      {/* Usage Summary */}
      {connected > 0 && (
        <div className="card" style={{ background: 'linear-gradient(135deg, rgba(139,92,246,0.08), rgba(236,72,153,0.05))', borderColor: 'rgba(139,92,246,0.25)' }}>
          <div style={{ fontSize: 11, color: 'var(--fg-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 700, marginBottom: 12 }}>
            📊 24-Hour Usage
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 12 }}>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Capacity</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{totalCapacity}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Used</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#f59e0b' }}>{totalUsed}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Remaining</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#10b981' }}>{totalCapacity - totalUsed}</div>
            </div>
          </div>
        </div>
      )}

      {/* Connect */}
      <div className="card">
        <h2 style={{ fontSize: 15, marginBottom: 12 }}>➕ Connect Gmail Account</h2>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <input
            className="input"
            style={{ flex: 1, minWidth: 200 }}
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
        <div style={{ marginTop: 12, padding: 12, borderRadius: 10, background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.2)', fontSize: 12, color: '#1e40af' }}>
          ⚠️ Google screen pe <b>"Send email on your behalf"</b> ko <b>ALLOW</b> karo
        </div>
      </div>

      {/* Sender list */}
      {loading ? (
        <div className="card text-center" style={{ padding: 40, color: 'var(--fg-muted)' }}>Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center" style={{ padding: 48 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
          <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>Koi sender connect nahi hai</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {list.map(s => {
            const cap = s.dailyLimit || 350;
            const used = s.sentToday || 0;
            const remaining = Math.max(0, cap - used);
            const pct = Math.min(100, (used / cap) * 100);

            return (
              <div key={s.id} className="card" style={{ padding: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 12, flexWrap: 'wrap' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0, flex: 1 }}>
                    <div style={{
                      width: 44, height: 44, borderRadius: 12,
                      background: s.status === 'CONNECTED' ? 'linear-gradient(135deg, #10b981, #059669)' : 'linear-gradient(135deg, #ef4444, #dc2626)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: '#fff', fontSize: 18, flexShrink: 0,
                    }}>
                      {s.status === 'CONNECTED' ? '✓' : '✕'}
                    </div>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--fg)' }}>
                        {s.email}
                      </div>
                      <div style={{ fontSize: 11, color: s.status === 'CONNECTED' ? '#10b981' : '#dc2626', marginTop: 2, fontWeight: 600 }}>
                        ● {s.status}
                      </div>
                    </div>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginBottom: 12 }}>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Sent Today</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fg)', marginTop: 2 }}>{used}/{cap}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Remaining</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: remaining > 50 ? '#10b981' : '#f59e0b', marginTop: 2 }}>{remaining}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Limit</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fg)', marginTop: 2 }}>{cap}</div>
                  </div>
                </div>

                <div style={{ width: '100%', height: 6, background: 'var(--bg-subtle)', borderRadius: 999, overflow: 'hidden', marginBottom: 12 }}>
                  <div style={{
                    height: '100%',
                    width: pct + '%',
                    background: pct >= 100 ? '#ef4444' : pct >= 70 ? '#f59e0b' : '#10b981',
                    transition: 'width .3s',
                  }} />
                </div>

                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    onClick={() => reconnect(s.email)}
                    disabled={busy}
                    className="btn btn-ghost"
                    style={{ flex: 1, fontSize: 13 }}
                  >
                    🔄 Reconnect
                  </button>
                  <button
                    onClick={() => disconnect(s.id, s.email)}
                    disabled={busy}
                    className="btn btn-danger"
                    style={{ flex: 1, fontSize: 13 }}
                  >
                    Disconnect
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function SendersPage() {
  return (
    <Suspense fallback={<div className="card text-center" style={{ padding: 40, color: 'var(--fg-muted)' }}>Loading...</div>}>
      <SendersInner />
    </Suspense>
  );
}
