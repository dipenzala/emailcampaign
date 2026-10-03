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
    const iv = setInterval(load, 5000);
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

  const resetCounters = async () => {
    if (!confirm('Reset daily counters for all senders?')) return;
    setBusy(true);
    try {
      await fetch('/api/senders/rotation', { method: 'PUT' });
      await load();
      toast('✅ Counters reset', 'success');
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const moveUp = async (index: number) => {
    if (index === 0) return;
    const s = senders[index];
    const prev = senders[index - 1];
    await update(s.id, { rotationOrder: prev.rotationOrder });
    await update(prev.id, { rotationOrder: s.rotationOrder });
  };

  const moveDown = async (index: number) => {
    if (index >= senders.length - 1) return;
    const s = senders[index];
    const next = senders[index + 1];
    await update(s.id, { rotationOrder: next.rotationOrder });
    await update(next.id, { rotationOrder: s.rotationOrder });
  };

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🔄 Sender Rotation</h1>
        <p className="subtitle">Ek ke baad ek — Sender 1 → Sender 2 → Sender 3 → wapas Sender 1</p>
      </div>

      {/* Current sender indicator */}
      <div className="card border-violet-500/30" style={{ background: 'rgba(139,92,246,0.05)' }}>
        <div className="text-xs text-slate-400 uppercase tracking-wider mb-2">Current Sender</div>
        <div className="text-lg font-bold text-violet-300">
          {currentSender ? `📤 ${currentSender}` : '⏸️ No sender available'}
        </div>
        <div className="text-xs text-slate-500 mt-1">
          {currentSender ? 'Abhi is bhej raha hai' : 'Sab senders cap pe hain'}
        </div>
      </div>

      {/* Info */}
      <div className="card border-blue-500/30 !p-4" style={{ background: 'rgba(59,130,246,0.05)' }}>
        <div className="text-xs text-blue-300">
          <div className="font-semibold mb-1">📋 Kaise Kaam Karta Hai</div>
          <div className="text-slate-400 leading-relaxed">
            Har sender <b>{senders[0]?.dailyLimit || 10}</b> emails bhejta hai, phir <b>next sender</b> activate hota hai.
            Agar aapka batch limit 10 hai, to:
            <br />Sender 1 → 10 emails
            <br />Sender 2 → 10 emails
            <br />Sender 3 → 10 emails
            <br />Wapas Sender 1 → ...
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-2 flex-wrap">
        <button onClick={resetCounters} disabled={busy} className="btn btn-ghost text-sm">
          🔄 Reset Counters
        </button>
        <button onClick={load} disabled={busy} className="btn btn-ghost text-sm">
          🔃 Refresh
        </button>
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
          {senders.map((s, index) => {
            const isCurrent = s.email === currentSender;
            const batchLimit = s.dailyLimit || 10;
            const batchPct = Math.min(100, (s.batchCount / batchLimit) * 100);

            return (
              <div
                key={s.id}
                className={`card !p-4 ${isCurrent ? 'border-violet-500/50 ring-2 ring-violet-500/20' : ''}`}
              >
                <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-sm flex-shrink-0 ${
                      isCurrent
                        ? 'bg-gradient-to-br from-violet-500 to-pink-500 text-white'
                        : 'bg-slate-800 text-slate-400'
                    }`}>
                      {index + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm truncate">{s.email}</div>
                      {isCurrent && (
                        <div className="text-[10px] text-violet-400 font-bold uppercase tracking-wider mt-0.5">
                          ▶️ Currently Active
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 flex-shrink-0">
                    <button
                      onClick={() => moveUp(index)}
                      disabled={index === 0 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                      title="Move up"
                    >▲</button>
                    <button
                      onClick={() => moveDown(index)}
                      disabled={index === senders.length - 1 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                      title="Move down"
                    >▼</button>
                  </div>
                </div>

                {/* Stats */}
                <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold">{s.sentToday}/{s.dailyLimit}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">BATCH</div>
                    <div className="font-semibold">{s.batchCount}/{batchLimit}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">REP</div>
                    <div className={`font-semibold ${s.reputationScore >= 80 ? 'text-emerald-400' : s.reputationScore >= 50 ? 'text-amber-400' : 'text-red-400'}`}>
                      {s.reputationScore}
                    </div>
                  </div>
                </div>

                {/* Batch progress bar */}
                <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mb-3">
                  <div
                    className={`h-full ${batchPct >= 100 ? 'bg-amber-500' : 'bg-violet-500'} transition-all`}
                    style={{ width: batchPct + '%' }}
                  />
                </div>

                {/* Active toggle + limit */}
                <div className="flex items-center gap-3 flex-wrap">
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
                    <label className="text-xs text-slate-400">Batch:</label>
                    <input
                      type="number"
                      min={1}
                      max={500}
                      value={batchLimit}
                      onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 10 })}
                      className="w-16 bg-white/5 border border-white/10 rounded-lg px-2 py-1 text-xs"
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
