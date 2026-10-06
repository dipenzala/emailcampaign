'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function ControlPage() {
  const [enabled, setEnabled] = useState<boolean>(true);
  const [status, setStatus] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  const load = async () => {
    try {
      const [c, s] = await Promise.all([
        fetch('/api/worker/control').then(r => r.json()),
        fetch('/api/worker/status').then(r => r.json()),
      ]);
      if (c.ok) setEnabled(c.enabled);
      if (s.ok) setStatus(s);
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  const toggle = async () => {
    setBusy(true);
    setMsg('');
    try {
      const newState = !enabled;
      const r = await fetch('/api/worker/control', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: newState }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      setEnabled(newState);
      setMsg(newState ? '✅ Worker turned ON' : '⏸️ Worker turned OFF');
      setTimeout(() => setMsg(''), 3000);
      load();
    } catch (e: any) {
      setMsg('❌ ' + e.message);
    }
    setBusy(false);
  };

  const isLive = status?.isLive;
  const secondsAgo = status?.secondsSinceLastSend;

  const formatAgo = (s: number | null) => {
    if (s === null) return 'never';
    if (s < 60) return `${s}s ago`;
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  };

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🎛️ Worker Control</h1>
        <p className="subtitle">Master switch for the sending worker</p>
      </div>

      {msg && (
        <div className="card" style={{
          padding: 14,
          background: msg.startsWith('❌') ? '#fef2f2' : '#f0fdf4',
          borderColor: msg.startsWith('❌') ? '#fca5a5' : '#86efac',
          color: msg.startsWith('❌') ? '#991b1b' : '#065f46',
          fontWeight: 600,
          fontSize: 13,
        }}>
          {msg}
        </div>
      )}

      {/* MASTER SWITCH */}
      <div className="card" style={{
        padding: 32,
        background: enabled
          ? 'linear-gradient(135deg, rgba(16,185,129,0.08), rgba(5,150,105,0.04))'
          : 'linear-gradient(135deg, rgba(239,68,68,0.06), rgba(220,38,38,0.03))',
        borderColor: enabled ? 'rgba(16,185,129,0.4)' : 'rgba(239,68,68,0.3)',
        borderWidth: 2,
        textAlign: 'center',
      }}>
        <div style={{ fontSize: 72, marginBottom: 12 }}>
          {enabled ? '🟢' : '🔴'}
        </div>
        <div style={{ fontSize: 24, fontWeight: 800, marginBottom: 8, color: enabled ? '#065f46' : '#991b1b' }}>
          Worker is {enabled ? 'ON' : 'OFF'}
        </div>
        <div style={{ fontSize: 13, color: 'var(--fg-muted)', marginBottom: 24 }}>
          {enabled
            ? 'Northflank worker emails bhej raha hai'
            : 'Northflank worker paused hai — koi email nahi jaayegi'}
        </div>

        <button
          onClick={toggle}
          disabled={busy}
          style={{
            padding: '18px 48px',
            fontSize: 18,
            fontWeight: 800,
            borderRadius: 16,
            border: 'none',
            cursor: busy ? 'not-allowed' : 'pointer',
            background: enabled
              ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
              : 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            color: '#fff',
            boxShadow: enabled
              ? '0 12px 32px -8px rgba(239,68,68,0.5)'
              : '0 12px 32px -8px rgba(16,185,129,0.5)',
            transition: 'all .3s',
            opacity: busy ? 0.6 : 1,
          }}
        >
          {busy ? '⏳ Updating...' : (enabled ? '⏸️ TURN OFF WORKER' : '▶️ TURN ON WORKER')}
        </button>
      </div>

      {/* STATUS */}
      {status && (
        <div className="card">
          <h2 style={{ fontSize: 15, marginBottom: 16 }}>📊 Live Status</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <StatusCard
              label="Worker State"
              value={enabled ? 'ON' : 'OFF'}
              color={enabled ? '#10b981' : '#ef4444'}
            />
            <StatusCard
              label="Sending Activity"
              value={isLive ? '🟢 LIVE' : '⚪ Idle'}
              color={isLive ? '#10b981' : 'var(--fg-muted)'}
            />
            <StatusCard
              label="Last Email Sent"
              value={formatAgo(secondsAgo)}
              color="var(--fg)"
            />
            <StatusCard
              label="Queued Emails"
              value={String(status.queued ?? 0)}
              color="#f59e0b"
            />
          </div>
        </div>
      )}

      {/* INFO */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>💡 Kaise Kaam Karta Hai</div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
            • <b>Worker ON:</b> Northflank emails bhejta hai normally
            <br />
            • <b>Worker OFF:</b> Worker emails nahi bhejega (kill switch)
            <br />
            • Setting <b>5-10 sec</b> me apply hoti hai
            <br />
            • Northflank continuously running rahega, bas send karna band kar dega
          </div>
        </div>
      </div>

      {/* QUICK LINKS */}
      <div className="card">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link href="/bulk" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            📧 Bulk Sender
          </Link>
          <Link href="/senders" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            🔐 Senders
          </Link>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            📊 Dashboard
          </Link>
        </div>
      </div>
    </div>
  );
}

function StatusCard({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 12, padding: 14 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>
        {value}
      </div>
    </div>
  );
}
