'use client';
import AutoSendLoop from '@/components/AutoSendLoop';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function CampaignLive() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params.id;
  const [s, setS] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);

  const loadStats = () => {
    fetch(`/api/campaigns/${id}/status`)
      .then(r => r.ok ? r.json() : null)
      .then(j => j && setS({ ...j.counts, status: j.campaign?.status, campaign: j.campaign }))
      .catch(() => {});
  };

  useEffect(() => {
    loadStats();
    const iv = setInterval(loadStats, 2000);
    return () => clearInterval(iv);
  }, [id]);

  const loadRecipients = () => {
    fetch(`/api/campaigns/${id}/recipients?status=${filter}`)
      .then(r => r.ok ? r.json() : [])
      .then(setRecipients)
      .catch(() => {});
  };

  useEffect(() => {
    loadRecipients();
    const iv = setInterval(loadRecipients, 3000);
    return () => clearInterval(iv);
  }, [id, filter]);

  const act = async (a: 'pause' | 'resume' | 'stop') => {
    if (a === 'stop' && !confirm('Stop campaign? Pending jobs removed.')) return;
    setBusy(true);
    try {
      await fetch(`/api/campaigns/${id}/${a}`, { method: 'POST' });
      toast(`Campaign ${a}d`, 'success');
      loadStats();
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const deleteCampaign = async () => {
    if (!confirm('Delete this campaign permanently?\n\nThis removes all recipients and history.')) return;
    setBusy(true);
    try {
      const r = await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      if (!r.ok) throw new Error('Delete failed');
      toast('Campaign deleted', 'success');
      router.push('/history');
    } catch (e: any) { toast(e.message, 'error'); setBusy(false); }
  };

  const filtered = recipients.filter(r =>
    !search || (r.email || '').toLowerCase().includes(search.toLowerCase()) || (r.name || '').toLowerCase().includes(search.toLowerCase())
  );

  const progress = s?.progress ?? 0;

  return (
    <div className="space-y-4 md:space-y-6">
      <AutoSendLoop
        campaignId={id as string}
        enabled={s?.status === 'RUNNING'}
      />
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold flex items-center gap-2">
            {s?.campaign?.name || 'Campaign'}
            <span className={`text-xs px-2 py-1 rounded-full ${
              s?.status === 'RUNNING' ? 'bg-blue-500/20 text-blue-400 animate-pulse' :
              s?.status === 'COMPLETED' ? 'bg-emerald-500/20 text-emerald-400' :
              s?.status === 'STOPPED' ? 'bg-slate-500/20 text-slate-400' :
              s?.status === 'PAUSED' ? 'bg-amber-500/20 text-amber-400' :
              'bg-slate-800 text-slate-400'
            }`}>{s?.status || '...'}</span>
          </h1>
          <p className="text-xs text-slate-500 mt-1">ID: {id.slice(-12)}</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          {s?.status === 'RUNNING' && <button onClick={() => act('pause')} disabled={busy} className="btn btn-ghost text-xs md:text-sm">⏸️ Pause</button>}
          {s?.status === 'PAUSED' && <button onClick={() => act('resume')} disabled={busy} className="btn btn-primary text-xs md:text-sm">▶️ Resume</button>}
          {s?.status !== 'COMPLETED' && s?.status !== 'STOPPED' && (
            <button onClick={() => act('stop')} disabled={busy} className="btn btn-danger text-xs md:text-sm">⏹️ Stop</button>
          )}
          <a href={`/api/campaigns/${id}/download`} className="btn btn-ghost text-xs md:text-sm" download>📥 Download</a>
          <button onClick={deleteCampaign} disabled={busy} className="btn btn-danger text-xs md:text-sm">🗑️ Delete</button>
          <Link href="/history" className="btn btn-ghost text-xs md:text-sm">← Back</Link>
        </div>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2 md:gap-3">
        <KPI label="TOTAL" value={s?.total ?? 0} />
        <KPI label="SENT" value={s?.sent ?? 0} color="text-blue-400" />
        <KPI label="DELIVERED" value={s?.delivered ?? 0} color="text-emerald-400" />
        <KPI label="FAILED" value={s?.failed ?? 0} color="text-red-400" />
        <KPI label="BOUNCED" value={s?.bounced ?? 0} color="text-orange-400" />
        <KPI label="PENDING" value={s?.pending ?? 0} color="text-amber-400" />
        <KPI label="SUPPRESSED" value={s?.suppressed ?? 0} color="text-slate-400" />
      </div>

      {/* Progress */}
      <div className="card">
        <div className="flex justify-between text-sm mb-2">
          <span className="font-medium">Progress</span>
          <span className="text-lg font-bold">{progress.toFixed(1)}%</span>
        </div>
        <div className="w-full h-3 bg-slate-800 rounded-full overflow-hidden">
          <div className="h-full bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full transition-all duration-500"
            style={{ width: progress + '%' }} />
        </div>
      </div>

      {/* Recipients */}
      <div className="card">
        <div className="space-y-3 mb-3">
          <input
            className="input text-sm"
            placeholder="🔍 Search email or name..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          <div className="flex gap-2 flex-wrap">
            {['ALL', 'QUEUED', 'PROCESSING', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED', 'SUPPRESSED'].map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`text-xs px-2.5 py-1.5 rounded-lg transition ${filter === f ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>

        <div className="max-h-96 overflow-auto -mx-4 md:mx-0">
          {/* Desktop */}
          <table className="hidden md:table w-full text-xs">
            <thead className="text-slate-400 text-left sticky top-0 bg-slate-900">
              <tr>
                <th className="p-2">Email</th>
                <th>Name</th>
                <th>Status</th>
                <th>Error</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id} className="border-t border-slate-800">
                  <td className="p-2 font-mono">{r.email}</td>
                  <td>{r.name || '—'}</td>
                  <td className={statusColor(r.status)}>{r.status}</td>
                  <td className="text-slate-500 truncate max-w-xs">{r.error ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Mobile */}
          <div className="md:hidden divide-y divide-white/5">
            {filtered.map(r => (
              <div key={r.id} className="p-3">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <span className="font-mono text-xs truncate flex-1">{r.email}</span>
                  <span className={`text-xs font-semibold flex-shrink-0 ${statusColor(r.status)}`}>{r.status}</span>
                </div>
                {r.name && <div className="text-[11px] text-slate-500">{r.name}</div>}
                {r.error && <div className="text-[10px] text-red-400 truncate">{r.error}</div>}
              </div>
            ))}
            {filtered.length === 0 && (
              <div className="p-8 text-center text-slate-500 text-xs">No recipients</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function KPI({ label, value, color = '' }: { label: string; value: number; color?: string }) {
  return (
    <div className="bg-slate-950 border border-slate-800 rounded-lg p-2.5 md:p-3">
      <div className="text-[9px] md:text-[10px] uppercase text-slate-500 tracking-wider">{label}</div>
      <div className={`text-lg md:text-xl font-bold ${color}`}>{(value || 0).toLocaleString()}</div>
    </div>
  );
}

function statusColor(s: string) {
  return s === 'DELIVERED' ? 'text-emerald-400' :
    s === 'SENT' ? 'text-blue-400' :
    s === 'FAILED' || s === 'BOUNCED' ? 'text-red-400' :
    s === 'SUPPRESSED' ? 'text-slate-500' :
    s === 'PROCESSING' ? 'text-purple-400' :
    'text-amber-400';
}
