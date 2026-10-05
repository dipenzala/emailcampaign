'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function WorkerPage() {
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0, remaining: 0 });
  const [ticks, setTicks] = useState(0);

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/process', { method: 'POST' });
      const j = await r.json();

      setTicks(t => t + 1);
      setStats(prev => ({
        sent: prev.sent + (j.sent ?? 0),
        failed: prev.failed + (j.failed ?? 0),
        processed: prev.processed + (j.processed ?? 0),
        remaining: j.remaining ?? 0,
      }));

      const time = new Date().toLocaleTimeString();
      const msg = j.message || `✅ ${j.sent || 0} sent | ❌ ${j.failed || 0} failed | 📬 ${j.remaining ?? 0} remaining`;
      setLogs(prev => [`[${time}] ${msg}`, ...prev.slice(0, 49)]);

      // Auto-stop if no remaining
      if (j.remaining === 0 && j.processed === 0) {
        setLogs(prev => [`[${time}] 🎉 All emails processed!`, ...prev]);
        setRunning(false);
      }
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev.slice(0, 49)]);
    }
  };

  useEffect(() => {
    if (!running) return;
    runOnce();
    const iv = setInterval(runOnce, 3000);
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🤖 Background Worker</h1>
        <p className="subtitle">Vercel pe hi emails process hongi</p>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
        <Stat label="TICKS" value={ticks} />
        <Stat label="SENT" value={stats.sent} color="#10b981" />
        <Stat label="FAILED" value={stats.failed} color="#ef4444" />
        <Stat label="REMAINING" value={stats.remaining} color="#f59e0b" />
      </div>

      {/* Controls */}
      <div className="card">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={() => setRunning(v => !v)}
            className={'btn ' + (running ? 'btn-danger' : 'btn-primary')}
            style={{ flex: 1, padding: 14, fontSize: 15 }}
          >
            {running ? '⏹️ Stop Worker' : '▶️ Start Worker'}
          </button>
          <button onClick={runOnce} className="btn btn-ghost" style={{ padding: 14 }}>
            ⏭️ Step Once
          </button>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ padding: 14 }}>
            Dashboard
          </Link>
        </div>

        <div style={{
          marginTop: 12, padding: 12, borderRadius: 10,
          background: running ? 'rgba(16,185,129,0.08)' : 'rgba(100,116,139,0.08)',
          border: '1px solid ' + (running ? 'rgba(16,185,129,0.3)' : 'rgba(100,116,139,0.2)'),
          fontSize: 12,
          color: running ? '#065f46' : '#475569',
          fontWeight: 600,
        }}>
          {running ? '🟢 Worker running — processing 10 emails every 3 seconds' : '⚪ Worker stopped'}
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
            <div style={{ color: '#64748b' }}>Click "Start Worker" to begin...</div>
          ) : (
            logs.map((l, i) => <div key={i}>{l}</div>)
          )}
        </div>
      </div>

      {/* Info */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>💡 Kaise Use Karo</div>
          <ol style={{ margin: 0, paddingLeft: 20, fontSize: 12, color: 'var(--fg-muted)' }}>
            <li>Campaign create karo (dashboard se)</li>
            <li>Ye page kholo</li>
            <li><b>"Start Worker"</b> click karo</li>
            <li>Emails automatically jaayengi (10 har 3 sec)</li>
            <li>Page open rakho jab tak campaign khatam ho</li>
          </ol>
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
