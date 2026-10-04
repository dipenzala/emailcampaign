'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function RotationPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [currentSender, setCurrentSender] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/senders/rotation');
      const j = await r.json();
      setSenders(j.senders || []);
      setCurrentSender(j.currentSender || null);
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
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
      toast(`✅ Reset ${j.reset} senders`, 'success');
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

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔄 Sender Rotation</h1>
        <p className="text-sm text-slate-400 mt-1">
          Strictly one-by-one · Sender 1 → Sender 2 → Sender 3 → wapas Sender 1
        </p>
      </div>

      {/* Current sender */}
      <div className="card border-violet-500/40" style={{ background: 'rgba(139,92,246,0.06)' }}>
        <div className="text-[10px] text-slate-500 uppercase tracking-widest mb-2 font-semibold">Current Turn</div>
        <div className="flex items-center gap-3">
          <div className="text-3xl">📤</div>
          <div className="min-w-0 flex-1">
            <div className="text-lg font-bold text-violet-300 truncate">
              {currentSender || 'No sender available'}
            </div>
            <div className="text-xs text-slate-500">
              {currentSender ? 'Abhi is ki baari hai' : 'Sab senders cap pe hain'}
            </div>
          </div>
        </div>
      </div>

      {/* Info banner */}
      <div className="card border-blue-500/30 !p-4" style={{ background: 'rgba(59,130,246,0.06)' }}>
        <div className="text-xs text-blue-300 leading-relaxed">
          <div className="font-bold mb-2">📋 Rotation Order</div>
          <div className="font-mono text-[11px] text-slate-400">
            {senders.map((s, i) => (
              <div key={s.id}>#{i + 1} {s.email}</div>
            ))}
          </div>
          <div className="mt-3 text-slate-500">
            Har email ke baad agla sender aayega. Ek baar me sirf ek sender active rahega.
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-2 flex-wrap">
        <button onClick={load} disabled={busy} className="btn btn-ghost text-sm">🔃 Refresh</button>
        <button onClick={resetAll} disabled={busy} className="btn btn-ghost text-sm">🔄 Reset Counters</button>
        <Link href="/senders" className="btn btn-ghost text-sm">+ Add Sender</Link>
      </div>

      {/* Sender list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : senders.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400 text-sm mb-4">Koi sender connected nahi</p>
          <Link href="/senders" className="btn btn-primary">+ Add Sender</Link>
        </div>
      ) : (
        <div className="space-y-3">
          {senders.map((s, i) => {
            const isCurrent = s.email === currentSender;
            const cap = s.dailyLimit || 500;
            const pct = Math.min(100, (s.sentToday / cap) * 100);

            return (
              <div
                key={s.id}
                className={`card !p-4 ${isCurrent ? 'border-violet-500/60 ring-2 ring-violet-500/25' : ''}`}
              >
                <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className={`w-11 h-11 rounded-xl flex items-center justify-center font-bold text-base flex-shrink-0 ${
                      isCurrent
                        ? 'bg-gradient-to-br from-violet-500 to-pink-500 text-white shadow-lg shadow-violet-500/40'
                        : 'bg-slate-800 text-slate-400'
                    }`}>
                      {isCurrent ? '▶' : i + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm truncate">{s.email}</div>
                      {isCurrent && (
                        <div className="text-[10px] text-violet-400 font-bold uppercase tracking-widest mt-0.5">
                          ● Active Now
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 flex-shrink-0">
                    <button
                      onClick={() => moveUp(i)}
                      disabled={i === 0 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                    >▲</button>
                    <button
                      onClick={() => moveDown(i)}
                      disabled={i === senders.length - 1 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                    >▼</button>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold">{s.sentToday}/{cap}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">BATCH</div>
                    <div className="font-semibold">{s.batchCount}/1</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">REP</div>
                    <div className={`font-semibold ${
                      s.reputationScore >= 80 ? 'text-emerald-400'
                      : s.reputationScore >= 50 ? 'text-amber-400'
                      : 'text-red-400'
                    }`}>{s.reputationScore}</div>
                  </div>
                </div>

                <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mb-3">
                  <div
                    className={`h-full ${pct >= 100 ? 'bg-red-500' : pct >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}`}
                    style={{ width: pct + '%' }}
                  />
                </div>

                <div className="flex items-center justify-between flex-wrap gap-3">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={s.isActive !== false}
                      onChange={e => update(s.id, { isActive: e.target.checked })}
                      className="w-4 h-4"
                    />
                    <span className="text-xs text-slate-400">Active</span>
                  </label>
                  <div className="flex items-center gap-2">
                    <label className="text-xs text-slate-400">Daily Limit:</label>
                    <input
                      type="number"
                      min={1}
                      max={500}
                      value={s.dailyLimit}
                      onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 500 })}
                      className="w-20 bg-white/5 border border-white/10 rounded-lg px-2 py-1 text-xs"
                    />
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
