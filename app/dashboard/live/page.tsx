'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function LiveDashboard() {
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [tick, setTick] = useState(0);

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats);
        setSenders(j.senders || []);
        setCampaign(j.campaign);
        setActivity(j.activity || []);
        setTick(t => t + 1);
      }
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 2000);
    return () => clearInterval(iv);
  }, []);

  const logout = async () => {
    await fetch('/api/auth/simple-logout', { method: 'POST' });
    window.location.href = '/login';
  };

  const progress = stats.total > 0 ? ((stats.total - stats.pending) / stats.total) * 100 : 0;

  return (
    <div className="min-h-screen bg-slate-950 text-white">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
            <span className="font-semibold tracking-tight text-sm">EmailCampaign</span>
          </div>
          <div className="flex items-center gap-1">
            <Link href="/dashboard/live" className="text-sm text-white px-3 py-1.5 rounded-lg bg-white/10">Live</Link>
            <Link href="/campaigns/new" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">+ New</Link>
            <Link href="/senders" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">Senders</Link>
            <Link href="/history" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">History</Link>
            <button onClick={logout} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5">Logout</button>
          </div>
        </div>
      </nav>

      <main className="max-w-6xl mx-auto px-6 py-8 space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-3xl font-semibold tracking-tight flex items-center gap-3">
              🔴 Live Dashboard
              <span className="text-xs px-2 py-1 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 animate-pulse">LIVE</span>
            </h1>
            <p className="text-sm text-slate-400 mt-1">
              Auto-refresh 2s · Last: {new Date().toLocaleTimeString()} · Tick #{tick}
            </p>
          </div>
          <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New Campaign</Link>
        </div>

        {/* Big KPIs */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <KPI label="TOTAL" value={stats.total} color="text-white" big />
          <KPI label="SENT" value={stats.sent} color="text-blue-400" big />
          <KPI label="PENDING" value={stats.pending} color="text-amber-400" big />
          <KPI label="FAILED" value={stats.failed} color="text-red-400" big />
        </div>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <KPI label="QUEUED" value={stats.queued} color="text-yellow-400" />
          <KPI label="PROCESSING" value={stats.processing} color="text-purple-400" />
          <KPI label="DELIVERED" value={stats.delivered} color="text-emerald-400" />
          <KPI label="BOUNCED" value={stats.bounced} color="text-orange-400" />
          <KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" />
        </div>

        {/* Progress */}
        <div className="card">
          <div className="flex justify-between text-sm mb-2">
            <span className="font-medium">Overall Progress</span>
            <span className="text-lg font-bold">{progress.toFixed(1)}%</span>
          </div>
          <div className="w-full h-4 bg-slate-800 rounded-full overflow-hidden">
            <div className="h-full bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 transition-all duration-500 rounded-full"
              style={{ width: progress + '%' }} />
          </div>
        </div>

        {/* Senders */}
        <div className="card">
          <h2 className="font-semibold mb-3">👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)</h2>
          {senders.length === 0 ? (
            <p className="text-sm text-slate-400">No senders connected</p>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-3">
              {senders.map((s, i) => {
                const usage = s.dailyLimit > 0 ? (s.sentToday / s.dailyLimit) * 100 : 0;
                return (
                  <div key={i} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                    <div className="text-xs text-slate-400 truncate">{s.email}</div>
                    <div className="flex items-center justify-between mt-2">
                      <span className={`text-xs ${s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}`}>● {s.status}</span>
                      <span className="text-xs text-slate-500">{s.sentToday}/{s.dailyLimit}</span>
                    </div>
                    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mt-2">
                      <div className={`h-full ${usage >= 100 ? 'bg-red-500' : usage >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}`}
                        style={{ width: Math.min(100, usage) + '%' }} />
                    </div>
                    <div className="flex justify-between mt-1 text-[10px] text-slate-500">
                      <span>Batch: {s.batchCount}</span>
                      <span>Rep: {s.reputationScore}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {campaign && (
          <div className="card border-emerald-500/30">
            <h2 className="font-semibold mb-3">📧 Latest Campaign
              <span className="ml-2 text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400">{campaign.status}</span>
            </h2>
            <div className="grid md:grid-cols-3 gap-3 text-sm">
              <div><div className="text-xs text-slate-500">Name</div><div className="font-medium">{campaign.name}</div></div>
              <div><div className="text-xs text-slate-500">Subject</div><div className="font-medium truncate">{campaign.subject}</div></div>
              <div><div className="text-xs text-slate-500">Created</div><div className="font-medium">{new Date(campaign.createdAt).toLocaleString()}</div></div>
            </div>
          </div>
        )}

        {/* Activity */}
        <div className="card">
          <h2 className="font-semibold mb-3">📜 Live Activity</h2>
          <div className="bg-black border border-slate-800 rounded-lg p-4 max-h-64 overflow-auto font-mono text-xs">
            {activity.length === 0 ? <div className="text-slate-500">Waiting for activity...</div> :
              activity.map((l, i) => <div key={i} className="text-emerald-300 py-0.5">{l}</div>)}
          </div>
        </div>
      </main>
    </div>
  );
}

function KPI({ label, value, color, big = false }: { label: string; value: number; color: string; big?: boolean }) {
  return (
    <div className={`${big ? 'card !p-5' : 'bg-slate-950 border border-slate-800 rounded-lg p-3'}`}>
      <div className={`text-[10px] uppercase text-slate-500 tracking-wider`}>{label}</div>
      <div className={`${big ? 'text-4xl' : 'text-xl'} font-bold mt-1 ${color}`}>{(value || 0).toLocaleString()}</div>
    </div>
  );
}
