'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function RotationPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [currentSender, setCurrentSender] = useState<string | null>(null);
  const [summary, setSummary] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/senders/rotation');
      const j = await r.json();
      setSenders(j.senders || []);
      setCurrentSender(j.currentSender || null);
      setSummary(j.summary || null);
    } catch {}
    setLoading(false);
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, []);

  const update = async (id: string, patch: any) => {
    setBusy(true);
    try {
      await fetch('/api/senders/rotation', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, ...patch }),
      });
      await load();
      toast('✅ Saved', 'success');
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const resetAll = async () => {
    if (!confirm('Reset counters for all senders?')) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/rotation', { method: 'PUT' });
      const j = await r.json();
      toast(`Reset ${j.reset} senders`, 'success');
      await load();
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const moveUp = async (i: number) => {
    if (i === 0) return;
    const s = senders[i], prev = senders[i - 1];
    await update(s.id, { rotationOrder: prev.rotationOrder });
    await update(prev.id, { rotationOrder: s.rotationOrder });
  };

  const moveDown = async (i: number) => {
    if (i >= senders.length - 1) return;
    const s = senders[i], next = senders[i + 1];
    await update(s.id, { rotationOrder: next.rotationOrder });
    await update(next.id, { rotationOrder: s.rotationOrder });
  };

  const MAX_LIMIT = 350;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔄 Sender Rotation</h1>
        <p className="text-sm text-slate-400 mt-1">
          Strictly one-by-one · Max {MAX_LIMIT} emails per sender per day
        </p>
      </div>

      {/* USAGE SUMMARY */}
      {summary && (
        <div className="card" style={{ background: 'linear-gradient(135deg, rgba(139,92,246,0.06), rgba(236,72,153,0.04))', borderColor: 'rgba(139,92,246,0.25)' }}>
          <div style={{ fontSize: 11, color: 'var(--fg-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 700, marginBottom: 12 }}>
            📊 24-Hour Usage
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 12, marginBottom: 16 }}>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Total Capacity</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.totalCapacity}</div>
              <div style={{ fontSize: 10, color: 'var(--fg-dim)' }}>{summary.senderCount} senders × {MAX_LIMIT}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Used Today</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#f59e0b' }}>{summary.totalUsed}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Remaining</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#10b981' }}>{summary.totalRemaining}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Usage</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.usagePct}%</div>
            </div>
          </div>
          <div style={{ height: 8, background: 'var(--bg-subtle)', borderRadius: 999, overflow: 'hidden' }}>
            <div style={{
              height: '100%',
              width: Math.min(100, summary.usagePct) + '%',
              background: summary.usagePct >= 90 ? '#ef4444' : summary.usagePct >= 70 ? '#f59e0b' : 'linear-gradient(90deg,#8b5cf6,#10b981)',
              transition: 'width .4s',
            }} />
          </div>
        </div>
      )}

      {/* Current turn */}
      <div className="card" style={{ borderColor: currentSender ? 'rgba(139,92,246,0.4)' : 'var(--border)' }}>
        <div style={{ fontSize: 10, color: 'var(--fg-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 700, marginBottom: 8 }}>
          Current Turn
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ fontSize: 32 }}>📤</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 700, color: '#8b5cf6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {currentSender || 'No sender available'}
            </div>
            <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
              {currentSender ? 'Abhi is ki baari hai' : 'Sab senders cap pe hain'}
            </div>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button onClick={load} disabled={busy} className="btn btn-ghost text-sm">🔃 Refresh</button>
        <button onClick={resetAll} disabled={busy} className="btn btn-ghost text-sm">🔄 Reset Counters</button>
        <Link href="/senders" className="btn btn-ghost text-sm">+ Add Sender</Link>
      </div>

      {/* Sender list */}
      {loading ? (
        <div className="card text-center" style={{ padding: 40, color: 'var(--fg-muted)' }}>Loading...</div>
      ) : senders.length === 0 ? (
        <div className="card text-center" style={{ padding: 48 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
          <p style={{ color: 'var(--fg-muted)', fontSize: 14, marginBottom: 16 }}>Koi sender connected nahi</p>
          <Link href="/senders" className="btn btn-primary">+ Add Sender</Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {senders.map((s, i) => {
            const isCurrent = s.email === currentSender;
            const cap = s.dailyLimit || MAX_LIMIT;
            const pct = Math.min(100, (s.sentToday / cap) * 100);
            const remaining = Math.max(0, cap - s.sentToday);

            return (
              <div key={s.id} className="card" style={{ padding: 16, borderColor: isCurrent ? 'rgba(139,92,246,0.5)' : undefined, boxShadow: isCurrent ? '0 0 0 3px rgba(139,92,246,0.15)' : undefined }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12, marginBottom: 12, flexWrap: 'wrap' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0 }}>
                    <div style={{
                      width: 44, height: 44, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center',
                      background: isCurrent ? 'linear-gradient(135deg,#8b5cf6,#ec4899)' : 'var(--bg-subtle)',
                      color: isCurrent ? '#fff' : 'var(--fg-dim)',
                      fontWeight: 700, fontSize: 15, flexShrink: 0,
                    }}>{isCurrent ? '▶' : i + 1}</div>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontSize: 14, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.email}</div>
                      {isCurrent && (
                        <div style={{ fontSize: 10, color: '#8b5cf6', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 }}>
                          ● Active Now
                        </div>
                      )}
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                    <button onClick={() => moveUp(i)} disabled={i === 0 || busy} className="topbar-btn" style={{ width: 32, height: 32, fontSize: 12 }}>▲</button>
                    <button onClick={() => moveDown(i)} disabled={i === senders.length - 1 || busy} className="topbar-btn" style={{ width: 32, height: 32, fontSize: 12 }}>▼</button>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, fontSize: 12, marginBottom: 12 }}>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase' }}>Used</div>
                    <div style={{ fontSize: 15, fontWeight: 700 }}>{s.sentToday}/{cap}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase' }}>Remaining</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: remaining > 50 ? '#10b981' : '#f59e0b' }}>{remaining}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase' }}>Rep</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: s.reputationScore >= 80 ? '#10b981' : s.reputationScore >= 50 ? '#f59e0b' : '#ef4444' }}>{s.reputationScore}</div>
                  </div>
                </div>

                <div style={{ width: '100%', height: 6, background: 'var(--bg-subtle)', borderRadius: 999, overflow: 'hidden', marginBottom: 12 }}>
                  <div style={{
                    height: '100%', width: pct + '%',
                    background: pct >= 100 ? '#ef4444' : pct >= 70 ? '#f59e0b' : '#10b981',
                  }} />
                </div>

                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={s.isActive !== false}
                      onChange={e => update(s.id, { isActive: e.target.checked })}
                      style={{ width: 16, height: 16 }}
                    />
                    <span style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Active</span>
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <label style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Daily Limit:</label>
                    <input
                      type="number"
                      min={1}
                      max={MAX_LIMIT}
                      value={s.dailyLimit}
                      onChange={e => update(s.id, { dailyLimit: Math.min(MAX_LIMIT, parseInt(e.target.value) || MAX_LIMIT) })}
                      className="input"
                      style={{ width: 80, padding: '6px 10px', fontSize: 13 }}
                    />
                    <span style={{ fontSize: 11, color: 'var(--fg-dim)' }}>max {MAX_LIMIT}</span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
