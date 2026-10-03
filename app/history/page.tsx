'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

type Campaign = {
  id: string;
  name: string;
  subject: string;
  status: string;
  totalCount: number;
  sentCount: number;
  failedCount: number;
  spamScore: number | null;
  createdAt: string;
  completedAt: string | null;
};

export default function HistoryPage() {
  const [list, setList] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [showCleanup, setShowCleanup] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/campaigns');
      const j = await r.json();
      setList(j);
    } catch { toast('Failed to load campaigns', 'error'); }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const filtered = list.filter(c => {
    if (filter !== 'ALL' && c.status !== filter) return false;
    if (search && !c.name.toLowerCase().includes(search.toLowerCase()) && !c.subject.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const toggleSelect = (id: string) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSelected(next);
  };

  const selectAll = () => {
    if (selected.size === filtered.length) {
      setSelected(new Set());
    } else {
      setSelected(new Set(filtered.map(c => c.id)));
    }
  };

  const deleteCampaign = async (id: string, name: string) => {
    if (!confirm(`Delete "${name}"?\n\nThis will remove the campaign and all its recipients.`)) return;
    setBusy(true);
    try {
      const r = await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      if (!r.ok) throw new Error('Delete failed');
      toast(`Deleted "${name}"`, 'success');
      await load();
      selected.delete(id);
      setSelected(new Set(selected));
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const deleteSelected = async () => {
    if (selected.size === 0) return;
    if (!confirm(`Delete ${selected.size} campaign(s)?`)) return;
    setBusy(true);
    try {
      for (const id of Array.from(selected)) {
        await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      }
      toast(`Deleted ${selected.size} campaigns`, 'success');
      setSelected(new Set());
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const deleteAll = async () => {
    const input = prompt('Type DELETE ALL (all caps) to confirm deleting EVERY campaign:');
    if (input !== 'DELETE ALL') { toast('Cancelled', 'info'); return; }
    setBusy(true);
    try {
      const r = await fetch('/api/campaigns/delete-all', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ confirm: 'DELETE ALL' }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`Deleted ${j.deleted} campaigns`, 'success');
      setSelected(new Set());
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const cleanup = async (action: string, label: string) => {
    if (!confirm(`${label}?`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/campaigns/cleanup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`${label}: ${j.deleted} item(s) removed`, 'success');
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const getStatusColor = (s: string) => {
    if (s === 'COMPLETED') return 'text-emerald-400';
    if (s === 'RUNNING') return 'text-blue-400';
    if (s === 'PAUSED') return 'text-amber-400';
    if (s === 'STOPPED') return 'text-slate-400';
    if (s === 'DRAFT') return 'text-purple-400';
    return 'text-slate-400';
  };

  const stats = {
    total: list.length,
    completed: list.filter(c => c.status === 'COMPLETED').length,
    running: list.filter(c => c.status === 'RUNNING').length,
    failed: list.filter(c => c.status === 'STOPPED' || c.failedCount > 0).length,
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">📜 Campaign History</h1>
          <p className="text-sm text-slate-400 mt-1">Manage, filter, and delete past campaigns</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New Campaign</Link>
          <button onClick={() => setShowCleanup(v => !v)} className="btn btn-ghost text-sm">
            🧹 Cleanup
          </button>
        </div>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard label="TOTAL" value={stats.total} color="text-white" />
        <StatCard label="COMPLETED" value={stats.completed} color="text-emerald-400" />
        <StatCard label="RUNNING" value={stats.running} color="text-blue-400" />
        <StatCard label="FAILED/STOPPED" value={stats.failed} color="text-red-400" />
      </div>

      {/* Cleanup panel */}
      {showCleanup && (
        <div className="card border-amber-500/30 animate-in">
          <h2 className="font-semibold mb-3">🧹 Cleanup Options</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
            <button onClick={() => cleanup('failed', 'Delete failed/bounced recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Failed + Bounced recipients
            </button>
            <button onClick={() => cleanup('sent', 'Delete sent recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Sent recipients
            </button>
            <button onClick={() => cleanup('suppressed', 'Delete suppressed recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Suppressed recipients
            </button>
            <button onClick={() => cleanup('empty-campaigns', 'Delete empty campaigns')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Empty campaigns
            </button>
            <button onClick={() => cleanup('old', 'Delete 30+ day old campaigns')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Campaigns 30+ days old
            </button>
            <button onClick={deleteAll} className="btn btn-danger text-xs justify-start" disabled={busy}>
              ⚠️ Delete ALL campaigns
            </button>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="card !p-4 space-y-3">
        <div className="flex flex-col md:flex-row gap-3">
          <input
            className="input flex-1"
            placeholder="🔍 Search campaigns..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          {['ALL', 'RUNNING', 'COMPLETED', 'PAUSED', 'STOPPED', 'DRAFT'].map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`text-xs px-3 py-1.5 rounded-lg transition ${filter === f ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}
            >
              {f}
            </button>
          ))}
        </div>
        {selected.size > 0 && (
          <div className="flex items-center justify-between bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2">
            <span className="text-sm text-red-300">{selected.size} selected</span>
            <button onClick={deleteSelected} className="btn btn-danger text-xs" disabled={busy}>
              🗑️ Delete Selected
            </button>
          </div>
        )}
      </div>

      {/* List */}
      {loading ? (
        <div className="card text-center py-12 text-slate-500">Loading...</div>
      ) : filtered.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-3">📭</div>
          <p className="text-slate-400">No campaigns found</p>
          <Link href="/campaigns/new" className="btn btn-primary mt-4 inline-flex">+ Create your first campaign</Link>
        </div>
      ) : (
        <>
          {/* Desktop table */}
          <div className="hidden md:block card !p-0 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
                <tr>
                  <th className="p-3 w-8">
                    <input type="checkbox" checked={selected.size === filtered.length && filtered.length > 0} onChange={selectAll} className="w-4 h-4" />
                  </th>
                  <th className="p-3">Campaign</th>
                  <th className="p-3 text-center">Total</th>
                  <th className="p-3 text-center">Sent</th>
                  <th className="p-3 text-center">Failed</th>
                  <th className="p-3 text-center">Status</th>
                  <th className="p-3">Created</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(c => (
                  <tr key={c.id} className="border-t border-white/5 hover:bg-white/[0.02] transition">
                    <td className="p-3">
                      <input type="checkbox" checked={selected.has(c.id)} onChange={() => toggleSelect(c.id)} className="w-4 h-4" />
                    </td>
                    <td className="p-3">
                      <div className="font-medium">{c.name}</div>
                      <div className="text-xs text-slate-500 truncate max-w-xs">{c.subject}</div>
                    </td>
                    <td className="p-3 text-center">{c.totalCount}</td>
                    <td className="p-3 text-center text-blue-400">{c.sentCount}</td>
                    <td className="p-3 text-center text-red-400">{c.failedCount}</td>
                    <td className="p-3 text-center">
                      <span className={`text-xs font-semibold ${getStatusColor(c.status)}`}>{c.status}</span>
                    </td>
                    <td className="p-3 text-xs text-slate-500">
                      {new Date(c.createdAt).toLocaleDateString()}
                      <div className="text-[10px]">{new Date(c.createdAt).toLocaleTimeString()}</div>
                    </td>
                    <td className="p-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Link href={`/campaigns/${c.id}`} className="text-xs px-2 py-1 rounded bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 transition">
                          Open
                        </Link>
                        <button
                          onClick={() => deleteCampaign(c.id, c.name)}
                          className="text-xs px-2 py-1 rounded bg-red-500/10 text-red-400 hover:bg-red-500/20 transition"
                          disabled={busy}
                        >
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="md:hidden space-y-3">
            {filtered.map(c => (
              <div key={c.id} className={`card !p-4 ${selected.has(c.id) ? 'ring-2 ring-violet-500' : ''}`}>
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="flex items-start gap-2 flex-1 min-w-0">
                    <input type="checkbox" checked={selected.has(c.id)} onChange={() => toggleSelect(c.id)} className="w-4 h-4 mt-1 flex-shrink-0" />
                    <div className="min-w-0 flex-1">
                      <div className="font-medium truncate">{c.name}</div>
                      <div className="text-xs text-slate-500 truncate">{c.subject}</div>
                    </div>
                  </div>
                  <span className={`text-xs font-semibold flex-shrink-0 ${getStatusColor(c.status)}`}>{c.status}</span>
                </div>
                <div className="grid grid-cols-3 gap-2 mb-3 text-center">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">TOTAL</div>
                    <div className="text-sm font-bold">{c.totalCount}</div>
                  </div>
                  <div className="bg-blue-500/10 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">SENT</div>
                    <div className="text-sm font-bold text-blue-400">{c.sentCount}</div>
                  </div>
                  <div className="bg-red-500/10 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">FAILED</div>
                    <div className="text-sm font-bold text-red-400">{c.failedCount}</div>
                  </div>
                </div>
                <div className="flex items-center justify-between text-xs text-slate-500 mb-3">
                  <span>{new Date(c.createdAt).toLocaleDateString()}</span>
                  <span>{new Date(c.createdAt).toLocaleTimeString()}</span>
                </div>
                <div className="flex gap-2">
                  <Link href={`/campaigns/${c.id}`} className="btn btn-ghost text-xs flex-1 justify-center">
                    Open
                  </Link>
                  <button
                    onClick={() => deleteCampaign(c.id, c.name)}
                    className="btn btn-danger text-xs flex-1 justify-center"
                    disabled={busy}
                  >
                    🗑️ Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="card !p-4">
      <div className="text-[10px] uppercase text-slate-500 tracking-wider">{label}</div>
      <div className={`text-2xl font-bold mt-1 ${color}`}>{value}</div>
    </div>
  );
}
