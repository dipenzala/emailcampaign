'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function WorkerPage() {
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0, remaining: 0 });
  const [ticks, setTicks] = useState(0);
  const [lastCheck, setLastCheck] = useState<string>('--:--:--');

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/process', { method: 'POST' });
      const j = await r.json();

      setTicks(t => t + 1);
      setLastCheck(new Date().toLocaleTimeString());

      if (j.sent > 0 || j.failed > 0 || j.processed > 0) {
        setStats(prev => ({
          sent: prev.sent + (j.sent ?? 0),
          failed: prev.failed + (j.failed ?? 0),
          processed: prev.processed + (j.processed ?? 0),
          remaining: j.remaining ?? 0,
        }));
      } else {
        setStats(prev => ({ ...prev, remaining: j.remaining ?? prev.remaining }));
      }

      const time = new Date().toLocaleTimeString();
      let msg: string;
      if (j.message === 'No queued recipients') {
        msg = `💤 No queued recipients`;
      } else {
        msg = `✅ ${j.sent || 0} sent | ❌ ${j.failed || 0} failed | 📬 ${j.remaining ?? 0} remaining`;
      }
      setLogs(prev => [`[${time}] ${msg}`, ...prev.slice(0, 30)]);
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev.slice(0, 30)]);
    }
  };

  useEffect(() => {
    // Auto-check status every 5 seconds (even when not "running")
    const iv = setInterval(() => {
      if (!running) {
        // Silent status check
        fetch('/api/worker/process', { method: 'POST' })
          .then(r => r.json())
          .then(j => {
            if (j.sent > 0 || j.processed > 0) {
              setStats(prev => ({
                sent: prev.sent + (j.sent ?? 0),
                failed: prev.failed + (j.failed ?? 0),
                processed: prev.processed + (j.processed ?? 0),
                remaining: j.remaining ?? 0,
              }));
              setLogs(prev => [`[${new Date().toLocaleTimeString()}] ⚡ Auto: ${j.sent || 0} sent | 📬 ${j.remaining ?? 0} remaining`, ...prev.slice(0, 30)]);
            }
          })
          .catch(() => {});
      }
    }, 5000);

    return () => clearInterval(iv);
  }, [running]);

  useEffect(() => {
    if (!running) return;
    runOnce();
    const iv = setInterval(runOnce, 2000);
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🤖 Background Worker</h1>
        <p className="subtitle">Emails automatically process ho rahi hain</p>
      </div>

      {/* AUTO STATUS BANNER */}
      <div className="card" style={{ background: 'rgba(16,185,129,0.06)', borderColor: 'rgba(16,185,129,0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
          <div style={{ fontSize: 32 }}>⚡</div>
          <div style={{ flex: 1, minWidth: 200 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: '#065f46', marginBottom: 4 }}>
              Auto-Worker Active
            </div>
            <div style={{ fontSize: 12, color: '#047857', lineHeight: 1.5 }}>
              Vercel Cron har 2 min me check karta hai + ye page har 5 sec me auto-trigger karta hai.
              <b> Koi manual start nahi chahiye.</b>
            </div>
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '6px 12px', borderRadius: 999,
            background: 'rgba(16,185,129,0.15)',
            fontSize: 11, fontWeight: 700, color: '#065f46',
          }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10b981' }} />
            AUTO-ON
          </div>
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
        <Stat label="CHECKS" value={ticks} />
        <Stat label="SENT" value={stats.sent} color="#10b981" />
        <Stat label="FAILED" value={stats.failed} color="#ef4444" />
        <Stat label="REMAINING" value={stats.remaining} color="#f59e0b" />
      </div>

      {/* Controls */}
      <div className="card">
        <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginBottom: 12, fontWeight: 600 }}>
          ⚙️ Manual override (optional — auto already chal raha hai)
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={() => setRunning(v => !v)}
            className={'btn ' + (running ? 'btn-danger' : 'btn-primary')}
            style={{ flex: 1, minWidth: 200, padding: 12 }}
          >
            {running ? '⏹️ Stop Fast Mode' : '⚡ Fast Mode (2 sec)'}
          </button>
          <button onClick={runOnce} className="btn btn-ghost" style={{ padding: 12 }}>
            ⏭️ Step Once
          </button>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ padding: 12 }}>
            Dashboard
          </Link>
        </div>
        <div style={{
          marginTop: 12, padding: 10, borderRadius: 8,
          background: 'var(--bg-subtle)',
          fontSize: 11, color: 'var(--fg-muted)',
          display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8,
        }}>
          <span>Status: <b style={{ color: '#10b981' }}>Auto</b></span>
          <span>Last check: <b>{lastCheck}</b></span>
          <span>Fast: <b>{running ? 'ON' : 'OFF'}</b></span>
        </div>
      </div>

      {/* Logs */}
      <div className="card">
        <h2 style={{ fontSize: 15, marginBottom: 12 }}>📜 Live Logs</h2>
        <div style={{
          background: '#0f172a', color: '#10b981',
          borderRadius: 12, padding: 16, maxHeight: 400, overflow: 'auto',
          fontFamily: 'monospace', fontSize: 11, lineHeight: 1.6,
        }}>
          {logs.length === 0 ? (
            <div style={{ color: '#64748b' }}>Auto-worker waiting for queued emails...</div>
          ) : (
            logs.map((l, i) => <div key={i}>{l}</div>)
          )}
        </div>
      </div>

      {/* Info */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 8 }}>⚡ Automatic Worker — Kaise Kaam Karta Hai</div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
            <div style={{ marginBottom: 6 }}>
              <b>1. Vercel Cron:</b> Har 2 minute me server khud <code>/api/cron/process</code> call karta hai — emails automatically process
            </div>
            <div style={{ marginBottom: 6 }}>
              <b>2. Page Auto-Trigger:</b> Ye page jab bhi koi kholta hai, har 5 sec me auto-trigger hoti hai
            </div>
            <div style={{ marginBottom: 6 }}>
              <b>3. Fast Mode:</b> Agar turant chahiye to ye button dabao — 2 sec me ek batch
            </div>
            <div style={{ marginTop: 10, padding: 10, background: 'rgba(16,185,129,0.08)', borderRadius: 8, color: '#065f46', fontWeight: 600 }}>
              ✅ Koi manual start nahi chahiye. Campaign start karte hi emails jaana shuru ho jayengi.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border)', borderRadius: 12, padding: 14 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 800, color, marginTop: 4 }}>{value.toLocaleString()}</div>
    </div>
  );
}
