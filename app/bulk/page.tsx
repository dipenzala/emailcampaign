'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import WorkerToggle from '@/components/WorkerToggle';

type LogEntry = { time: string; text: string; type: 'info' | 'success' | 'error' | 'warn' };
type OpenedItem = {
  id: string;
  email: string;
  name?: string;
  company?: string;
  openCount: number;
  firstOpenedAt?: string;
  lastOpenedAt?: string;
  sentAt?: string;
  campaignName?: string;
  senderEmail?: string;
  senderName?: string;
};

export default function BulkWorkerPage() {
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0, remaining: 0, ticks: 0 });
  const [batchSize, setBatchSize] = useState(20);
  const [intervalSec, setIntervalSec] = useState(5);
  const [autoMode, setAutoMode] = useState(true);
  const [autoInfo, setAutoInfo] = useState<any>(null);

  const [tab, setTab] = useState<'worker' | 'opened'>('worker');
  const [opened, setOpened] = useState<OpenedItem[]>([]);
  const [openedStats, setOpenedStats] = useState<any>(null);
  const [openedLoading, setOpenedLoading] = useState(false);

  const runningRef = useRef(false);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const statsRef = useRef({ sent: 0, failed: 0, processed: 0, remaining: 0, ticks: 0 });

  const addLog = (text: string, type: LogEntry['type'] = 'info') => {
    const time = new Date().toLocaleTimeString();
    setLogs(prev => [{ time, text, type }, ...prev.slice(0, 99)]);
  };

  // ═══════════════════════════════════════════
  // AUTO-DETECT CONFIG
  // ═══════════════════════════════════════════
  const fetchAutoConfig = async () => {
    try {
      const r = await fetch('/api/worker/auto-config');
      const j = await r.json();
      if (j.ok) {
        setAutoInfo(j);
        if (autoMode) {
          setBatchSize(j.batchSize);
          setIntervalSec(j.intervalSec);
        }
      }
    } catch {}
  };

  useEffect(() => {
    fetchAutoConfig();
    const iv = setInterval(fetchAutoConfig, 15000);
    return () => clearInterval(iv);
  }, [autoMode]);

  // ═══════════════════════════════════════════
  // FETCH OPENED LIST
  // ═══════════════════════════════════════════
  const fetchOpened = async () => {
    setOpenedLoading(true);
    try {
      const r = await fetch('/api/opened?limit=200');
      const j = await r.json();
      if (j.ok) {
        setOpened(j.items || []);
        setOpenedStats(j.stats);
      }
    } catch {}
    setOpenedLoading(false);
  };

  useEffect(() => {
    if (tab === 'opened') {
      fetchOpened();
      const iv = setInterval(fetchOpened, 5000);
      return () => clearInterval(iv);
    }
  }, [tab]);

  // ═══════════════════════════════════════════
  // WORKER
  // ═══════════════════════════════════════════
  const runOnce = async () => {
    try {
      const r = await fetch(`/api/worker/bulk?batch=${batchSize}`, { method: 'POST' });
      const j = await r.json();

      const newStats = {
        sent: statsRef.current.sent + (j.sent ?? 0),
        failed: statsRef.current.failed + (j.failed ?? 0),
        processed: statsRef.current.processed + (j.processed ?? 0),
        remaining: j.remaining ?? 0,
        ticks: statsRef.current.ticks + 1,
      };
      statsRef.current = newStats;
      setStats(newStats);

      if (j.message === 'No queued recipients') {
        addLog('💤 No queued emails — waiting', 'info');
      } else {
        addLog(
          `✅ Sent ${j.sent ?? 0} | ❌ Failed ${j.failed ?? 0} | 📬 Remaining ${j.remaining ?? 0}`,
          (j.failed ?? 0) > 0 ? 'warn' : 'success'
        );
      }

      if ((j.remaining ?? 0) === 0 && (j.sent ?? 0) === 0 && (j.processed ?? 0) === 0) {
        addLog('🎉 All emails sent! Stopping worker...', 'success');
        stopWorker();
      }
    } catch (e: any) {
      addLog(`❌ Network error: ${e.message}`, 'error');
    }
  };

  const startWorker = () => {
    if (runningRef.current) return;
    runningRef.current = true;
    setRunning(true);
    addLog(`▶️ Started (batch: ${batchSize}, interval: ${intervalSec}s, auto: ${autoMode ? 'ON' : 'OFF'})`, 'success');
    runOnce();
    intervalRef.current = setInterval(() => {
      if (!runningRef.current) return;
      runOnce();
    }, intervalSec * 1000);
  };

  const stopWorker = () => {
    runningRef.current = false;
    setRunning(false);
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
    addLog('⏹️ Worker stopped', 'warn');
  };

  const toggleWorker = () => {
    if (runningRef.current) stopWorker();
    else startWorker();
  };

  useEffect(() => {
    return () => {
      runningRef.current = false;
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);

  const resetStats = () => {
    statsRef.current = { sent: 0, failed: 0, processed: 0, remaining: 0, ticks: 0 };
    setStats({ sent: 0, failed: 0, processed: 0, remaining: 0, ticks: 0 });
    addLog('🔄 Stats reset', 'info');
  };

  const emailsPerMin = Math.round((batchSize / intervalSec) * 60);

  return (
    <div className="space-y-5">
      {/* HEADER */}
      <div className="page-header">
        <h1>📧 Bulk Mail Worker</h1>
        <p className="subtitle">
          Har {intervalSec}s me {batchSize} emails · ~{emailsPerMin}/min
        </p>
      </div>

      {/* Worker ON/OFF toggle */}
      <WorkerToggle variant="card" />

      {/* TABS */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button
          onClick={() => setTab('worker')}
          className={'btn ' + (tab === 'worker' ? 'btn-primary' : 'btn-ghost')}
          style={{ flex: 1, minWidth: 140 }}
        >
          📧 Sender
        </button>
        <button
          onClick={() => setTab('opened')}
          className={'btn ' + (tab === 'opened' ? 'btn-primary' : 'btn-ghost')}
          style={{ flex: 1, minWidth: 140 }}
        >
          👁️ Opened ({openedStats?.totalOpened ?? 0})
        </button>
      </div>

      {/* ═══════════════════════════════════════════ */}
      {/* TAB: WORKER */}
      {/* ═══════════════════════════════════════════ */}
      {tab === 'worker' && (
        <>
          {/* AUTO-DETECT BANNER */}
          <div className="card" style={{
            background: 'linear-gradient(135deg, rgba(139,92,246,0.08), rgba(236,72,153,0.04))',
            borderColor: 'rgba(139,92,246,0.3)',
          }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, flexWrap: 'wrap' }}>
              <div style={{ fontSize: 32 }}>🤖</div>
              <div style={{ flex: 1, minWidth: 200 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6, flexWrap: 'wrap' }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#6d28d9' }}>
                    Auto-Detect: {autoInfo?.mode?.toUpperCase() || 'LOADING'}
                  </div>
                  <label style={{
                    display: 'inline-flex', alignItems: 'center', gap: 6,
                    padding: '3px 10px', borderRadius: 999,
                    background: autoMode ? 'rgba(16,185,129,0.15)' : 'rgba(100,116,139,0.15)',
                    fontSize: 10, fontWeight: 700, cursor: 'pointer',
                  }}>
                    <input
                      type="checkbox"
                      checked={autoMode}
                      onChange={e => setAutoMode(e.target.checked)}
                      style={{ width: 12, height: 12 }}
                    />
                    {autoMode ? 'AUTO ON' : 'AUTO OFF'}
                  </label>
                </div>
                <div style={{ fontSize: 12, color: '#5b21b6', lineHeight: 1.6 }}>
                  {autoInfo?.reasoning || 'Fetching...'}
                </div>
                {autoInfo?.queue && (
                  <div style={{
                    display: 'flex', gap: 12, marginTop: 8, fontSize: 11,
                    color: '#6d28d9', flexWrap: 'wrap',
                  }}>
                    <span>📬 Queue: <b>{autoInfo.queue.queued}</b></span>
                    <span>👥 Senders: <b>{autoInfo.queue.senders}</b></span>
                    <span>💪 Capacity: <b>{autoInfo.queue.totalCapacity}</b></span>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* BIG START BUTTON */}
          <div className="card" style={{
            padding: 24,
            background: running
              ? 'linear-gradient(135deg, rgba(16,185,129,0.08), rgba(5,150,105,0.04))'
              : 'linear-gradient(135deg, rgba(139,92,246,0.06), rgba(236,72,153,0.03))',
            borderColor: running ? 'rgba(16,185,129,0.4)' : 'rgba(139,92,246,0.3)',
            borderWidth: 2,
          }}>
            <button
              onClick={toggleWorker}
              style={{
                width: '100%', padding: '20px 24px', fontSize: 20, fontWeight: 800,
                borderRadius: 16, border: 'none', cursor: 'pointer',
                background: running
                  ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
                  : 'linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%)',
                color: '#fff',
                boxShadow: running
                  ? '0 12px 32px -8px rgba(239,68,68,0.5)'
                  : '0 12px 32px -8px rgba(139,92,246,0.5)',
                transition: 'all .3s',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12,
              }}
            >
              <span style={{ fontSize: 28 }}>{running ? '⏹️' : '▶️'}</span>
              <span>{running ? 'STOP' : 'START'}</span>
            </button>
            <div style={{
              marginTop: 14, display: 'flex', alignItems: 'center',
              justifyContent: 'center', gap: 16, fontSize: 12,
              color: 'var(--fg-muted)', flexWrap: 'wrap',
            }}>
              <span>Status: <b style={{ color: running ? '#10b981' : 'var(--fg-muted)' }}>{running ? '🟢 SENDING' : '⚪ IDLE'}</b></span>
              <span>Speed: <b>~{emailsPerMin}/min</b></span>
            </div>
          </div>

          {/* STATS */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))', gap: 10 }}>
            <Stat label="TICKS" value={stats.ticks} />
            <Stat label="SENT" value={stats.sent} color="#10b981" />
            <Stat label="FAILED" value={stats.failed} color="#ef4444" />
            <Stat label="REMAINING" value={stats.remaining} color="#f59e0b" />
          </div>

          {/* CONFIG */}
          <div className="card">
            <h2 style={{ fontSize: 14, marginBottom: 12 }}>⚙️ Config</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
              <div>
                <label style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 600, marginBottom: 4, display: 'block' }}>
                  Batch size (1-50)
                </label>
                <input
                  type="number" className="input" min={1} max={50}
                  value={batchSize}
                  onChange={e => setBatchSize(Math.max(1, Math.min(50, parseInt(e.target.value) || 20)))}
                  disabled={running || autoMode}
                />
              </div>
              <div>
                <label style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 600, marginBottom: 4, display: 'block' }}>
                  Interval (seconds)
                </label>
                <input
                  type="number" className="input" min={2} max={60}
                  value={intervalSec}
                  onChange={e => setIntervalSec(Math.max(2, Math.min(60, parseInt(e.target.value) || 5)))}
                  disabled={running || autoMode}
                />
              </div>
            </div>
          </div>

          {/* QUICK ACTIONS */}
          <div className="card">
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button onClick={runOnce} className="btn btn-ghost" style={{ flex: 1, minWidth: 120 }}>⏭️ Step</button>
              <button onClick={resetStats} className="btn btn-ghost" style={{ flex: 1, minWidth: 120 }}>🔄 Reset</button>
              <button onClick={() => setLogs([])} className="btn btn-ghost" style={{ flex: 1, minWidth: 120 }}>🗑️ Clear</button>
              <Link href="/dashboard/live" className="btn btn-ghost" style={{ flex: 1, minWidth: 120 }}>📊 Dashboard</Link>
            </div>
          </div>

          {/* LOGS */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h2 style={{ fontSize: 14 }}>📜 Live Logs</h2>
              <span style={{ fontSize: 11, color: 'var(--fg-dim)' }}>{logs.length} entries</span>
            </div>
            <div style={{
              background: '#0f172a', color: '#e2e8f0', borderRadius: 12, padding: 16,
              maxHeight: 300, overflow: 'auto', fontFamily: 'monospace', fontSize: 11, lineHeight: 1.7,
            }}>
              {logs.length === 0 ? (
                <div style={{ color: '#64748b' }}>Click START to begin...</div>
              ) : (
                logs.map((l, i) => (
                  <div key={i} style={{
                    color: l.type === 'success' ? '#10b981'
                      : l.type === 'error' ? '#ef4444'
                      : l.type === 'warn' ? '#f59e0b'
                      : '#cbd5e1',
                    paddingBottom: 2,
                  }}>
                    <span style={{ color: '#64748b' }}>[{l.time}]</span> {l.text}
                  </div>
                ))
              )}
            </div>
          </div>
        </>
      )}

      {/* ═══════════════════════════════════════════ */}
      {/* TAB: OPENED */}
      {/* ═══════════════════════════════════════════ */}
      {tab === 'opened' && (
        <>
          {/* STATS */}
          {openedStats && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: 12 }}>
              <Stat label="OPENED" value={openedStats.totalOpened} color="#ec4899" />
              <Stat label="SENT" value={openedStats.totalSent} color="#3b82f6" />
              <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border)', borderRadius: 12, padding: 14 }}>
                <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>OPEN RATE</div>
                <div style={{ fontSize: 22, fontWeight: 800, color: '#a855f7', marginTop: 4 }}>{openedStats.openRate}%</div>
              </div>
            </div>
          )}

          {/* INFO */}
          <div className="card" style={{ background: 'rgba(236,72,153,0.05)', borderColor: 'rgba(236,72,153,0.2)' }}>
            <div style={{ fontSize: 12, color: '#9d174d', lineHeight: 1.6 }}>
              <b>👁️ Email Open Tracking</b>
              <br />
              Jab recipient email kholta hai, 1x1 pixel load hota hai aur yahan record ho jata hai.
              <br />
              <span style={{ color: 'var(--fg-muted)' }}>
                ⚠️ Gmail images block karta hai by default. Recipient "Show images" kare to count hoga.
              </span>
            </div>
          </div>

          {/* LIST */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
              <h2 style={{ fontSize: 14 }}>👥 Who Opened</h2>
              <button onClick={fetchOpened} disabled={openedLoading} className="btn btn-ghost" style={{ fontSize: 12, padding: '6px 12px' }}>
                {openedLoading ? '⏳' : '🔄 Refresh'}
              </button>
            </div>

            {opened.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 20px' }}>
                <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
                <div style={{ fontSize: 13, color: 'var(--fg-muted)' }}>
                  {openedLoading ? 'Loading...' : 'Abhi tak kisi ne open nahi kiya'}
                </div>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {opened.map(item => (
                  <div key={item.id} style={{
                    padding: 14, borderRadius: 12,
                    background: 'var(--bg-subtle)',
                    border: '1px solid var(--border)',
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>
                      <div style={{ minWidth: 0, flex: 1 }}>
                        <div style={{ fontWeight: 700, fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {item.name || item.email}
                        </div>
                        {item.name && (
                          <div style={{ fontSize: 11, color: 'var(--fg-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {item.email}
                          </div>
                        )}
                      </div>
                      <div style={{
                        display: 'flex', alignItems: 'center', gap: 4,
                        padding: '4px 10px', borderRadius: 999,
                        background: 'rgba(236,72,153,0.15)',
                        color: '#ec4899',
                        fontSize: 10, fontWeight: 700,
                        flexShrink: 0,
                      }}>
                        👁️ {item.openCount}x
                      </div>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 6, fontSize: 10, color: 'var(--fg-muted)' }}>
                      <div>
                        <b>Campaign:</b> {item.campaignName?.slice(0, 25) || '—'}
                      </div>
                      <div>
                        <b>Sent by:</b> {item.senderName || item.senderEmail || '—'}
                      </div>
                      <div>
                        <b>Sent:</b> {item.sentAt ? new Date(item.sentAt).toLocaleString() : '—'}
                      </div>
                      <div>
                        <b>Last opened:</b> {item.lastOpenedAt ? new Date(item.lastOpenedAt).toLocaleString() : '—'}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
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
