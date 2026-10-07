'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function ScheduledCampaignsPage() {
  const [list, setList] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/campaigns/scheduled');
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

  const now = new Date();
  const currentMin = now.getHours() * 60 + now.getMinutes();

  const isActiveNow = (c: any) => {
    const start = c.scheduleStartHour * 60 + c.scheduleStartMinute;
    const end = start + c.scheduleDurationMinutes;
    return currentMin >= start && currentMin < end;
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">⏰ Scheduled Campaigns</h1>
          <p className="text-sm text-slate-400 mt-1">Daily time-window bulk sends</p>
        </div>
        <Link href="/campaigns/scheduled/new" className="btn btn-primary">+ New Scheduled</Link>
      </div>

      {/* Current time banner */}
      <div className="card" style={{ background: 'rgba(139,92,246,0.06)', borderColor: 'rgba(139,92,246,0.25)' }}>
        <div className="text-sm">
          Current server time: <b>{String(now.getHours()).padStart(2, '0')}:{String(now.getMinutes()).padStart(2, '0')}</b>
        </div>
      </div>

      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-3">⏰</div>
          <p className="text-slate-400 mb-4">No scheduled campaigns yet</p>
          <Link href="/campaigns/scheduled/new" className="btn btn-primary">+ Create First</Link>
        </div>
      ) : (
        <div className="space-y-3">
          {list.map(c => {
            const active = isActiveNow(c) && c.status === 'RUNNING';
            const start = `${String(c.scheduleStartHour).padStart(2, '0')}:${String(c.scheduleStartMinute).padStart(2, '0')}`;
            const endMin = c.scheduleStartHour * 60 + c.scheduleStartMinute + c.scheduleDurationMinutes;
            const end = `${String(Math.floor(endMin / 60) % 24).padStart(2, '0')}:${String(endMin % 60).padStart(2, '0')}`;
            const sent = c.sentCount || 0;
            const total = c.totalCount || 0;
            const progress = total > 0 ? (sent / total) * 100 : 0;

            return (
              <div key={c.id} className="card" style={{
                borderColor: active ? 'rgba(16,185,129,0.4)' : undefined,
                borderWidth: active ? 2 : 1,
              }}>
                <div className="flex items-start justify-between gap-3 flex-wrap mb-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-base">{c.name}</span>
                      <span className={`text-xs px-2 py-1 rounded font-bold ${
                        active ? 'bg-emerald-100 text-emerald-700 animate-pulse' :
                        c.status === 'COMPLETED' ? 'bg-slate-100 text-slate-600' :
                        c.status === 'RUNNING' ? 'bg-blue-100 text-blue-700' :
                        'bg-amber-100 text-amber-700'
                      }`}>
                        {active ? '🟢 ACTIVE NOW' : c.status}
                      </span>
                    </div>
                    <div className="text-xs text-slate-500 mt-1 truncate">{c.subject}</div>
                  </div>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                  <Info label="TIME WINDOW" value={`${start} → ${end}`} />
                  <Info label="DURATION" value={`${c.scheduleDurationMinutes / 60}h`} />
                  <Info label="TOTAL" value={total.toLocaleString()} />
                  <Info label="SENT" value={sent.toLocaleString()} color="#10b981" />
                </div>

                <div className="mb-3">
                  <div className="flex justify-between text-xs text-slate-500 mb-1">
                    <span>Progress</span>
                    <span>{progress.toFixed(1)}%</span>
                  </div>
                  <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
                    <div
                      className="h-full transition-all"
                      style={{
                        width: progress + '%',
                        background: progress >= 100 ? '#10b981' : 'linear-gradient(90deg,#8b5cf6,#ec4899)',
                      }}
                    />
                  </div>
                </div>

                <div className="flex gap-2 flex-wrap">
                  <Link href={`/campaigns/${c.id}`} className="btn btn-ghost text-xs">📊 Details</Link>
                  <span className="text-xs text-slate-400 self-center">
                    Last active: {c.lastActiveDate ? new Date(c.lastActiveDate).toLocaleString() : 'never'}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function Info({ label, value, color = 'var(--fg)' }: { label: string; value: string; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
      <div style={{ fontSize: 9, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>{label}</div>
      <div style={{ fontSize: 14, fontWeight: 700, color, marginTop: 3 }}>{value}</div>
    </div>
  );
}
