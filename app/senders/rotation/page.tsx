'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
export default function RotationPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const load = async () => { const r = await fetch('/api/senders/rotation'); const j = await r.json(); setSenders(j.senders ?? []); };
  useEffect(() => { load(); const iv = setInterval(load, 5000); return () => clearInterval(iv); }, []);
  const update = async (id: string, patch: any) => { setBusy(true); await fetch('/api/senders/rotation', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id, ...patch }) }); await load(); setBusy(false); setMsg('✅ Saved'); setTimeout(() => setMsg(''), 2000); };
  const resetAll = async () => { if (!confirm('Reset all daily counters?')) return; setBusy(true); await fetch('/api/senders/rotation', { method: 'PUT' }); await load(); setBusy(false); setMsg('✅ Reset'); setTimeout(() => setMsg(''), 2000); };
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">🔄 Sender Rotation</h1>
          <p className="text-sm text-slate-400 mt-1">Round-robin: each sender sends N emails, then next.</p>
        </div>
        <div className="flex gap-2">
          <button onClick={resetAll} className="btn btn-ghost text-sm" disabled={busy}>Reset Counters</button>
          <Link href="/senders" className="btn btn-ghost text-sm">← Senders</Link>
        </div>
      </div>
      {msg && <div className="card text-sm text-green-400">{msg}</div>}
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">#</th><th className="p-3">Sender</th><th className="p-3">Status</th><th className="p-3">Active</th><th className="p-3">Sent Today</th><th className="p-3">Batch</th><th className="p-3">Limit</th><th className="p-3">Warmup</th><th className="p-3">Reputation</th></tr>
          </thead>
          <tbody>
            {senders.map((s, i) => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3 text-slate-500">{i + 1}</td>
                <td className="p-3"><div className="font-medium text-xs">{s.email}</div></td>
                <td className="p-3"><span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>{s.status}</span></td>
                <td className="p-3"><input type="checkbox" checked={s.isActive} onChange={e => update(s.id, { isActive: e.target.checked })} /></td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3">{s.batchCount} / {s.dailyLimit}</td>
                <td className="p-3"><input type="number" value={s.dailyLimit} onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 10 })} className="w-16 bg-white/5 border border-white/10 rounded px-2 py-1 text-xs" /></td>
                <td className="p-3">{s.warmupEnabled ? <span className="text-xs px-2 py-0.5 rounded bg-blue-500/20 text-blue-300">Day {s.warmupDay}</span> : <span className="text-xs text-slate-500">off</span>}</td>
                <td className="p-3"><div className="w-16 h-1.5 bg-white/10 rounded-full overflow-hidden"><div className={s.reputationScore >= 80 ? 'bg-green-500 h-full' : s.reputationScore >= 50 ? 'bg-amber-500 h-full' : 'bg-red-500 h-full'} style={{ width: `${s.reputationScore}%` }} /></div></td>
              </tr>
            ))}
            {senders.length === 0 && <tr><td colSpan={9} className="p-8 text-center text-slate-500">No senders. <Link href="/senders" className="text-blue-400 underline">Add one</Link></td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
