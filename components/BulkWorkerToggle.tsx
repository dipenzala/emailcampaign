'use client';
import { useEffect, useState } from 'react';

type Props = {
  variant?: 'topbar' | 'card' | 'inline';
  showLabel?: boolean;
};

export default function BulkWorkerToggle({ variant = 'inline', showLabel = true }: Props) {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<any>(null);

  const load = async () => {
    try {
      const [c, s] = await Promise.all([
        fetch('/api/worker/bulk-control').then(r => r.json()),
        fetch('/api/worker/bulk-status').then(r => r.json()),
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
    if (busy || enabled === null) return;
    setBusy(true);
    const newState = !enabled;
    setEnabled(newState);
    try {
      const r = await fetch('/api/worker/bulk-control', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: newState }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      load();
    } catch {
      setEnabled(!newState);
    }
    setBusy(false);
  };

  const isLive = status?.isLive;
  const isLoading = enabled === null;

  if (variant === 'topbar') {
    return (
      <button
        onClick={toggle}
        disabled={busy || isLoading}
        title={enabled ? 'Bulk Worker ON — click to pause' : 'Bulk Worker OFF — click to resume'}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '8px 12px',
          borderRadius: 999,
          border: '1px solid',
          borderColor: enabled ? 'rgba(59,130,246,0.4)' : 'rgba(239,68,68,0.4)',
          background: enabled
            ? 'linear-gradient(135deg, rgba(59,130,246,0.12), rgba(99,102,241,0.06))'
            : 'linear-gradient(135deg, rgba(239,68,68,0.1), rgba(220,38,38,0.05))',
          color: enabled ? '#1e40af' : '#991b1b',
          fontSize: 12,
          fontWeight: 700,
          cursor: busy || isLoading ? 'not-allowed' : 'pointer',
          height: 40,
          flexShrink: 0,
          opacity: isLoading ? 0.6 : 1,
        }}
      >
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: enabled ? '#3b82f6' : '#ef4444',
            boxShadow: enabled ? '0 0 8px #3b82f6' : '0 0 8px #ef4444',
            animation: enabled && isLive ? 'bulkPulse 2s infinite' : 'none',
          }}
        />
        <span style={{ fontSize: 13 }}>📧</span>
        {showLabel && (
          <span className="hide-bulk-mobile">
            {isLoading ? '...' : enabled ? 'Bulk ON' : 'Bulk OFF'}
          </span>
        )}
        {enabled && isLive && (
          <span
            className="hide-bulk-mobile"
            style={{
              fontSize: 9,
              padding: '2px 6px',
              borderRadius: 999,
              background: 'rgba(59,130,246,0.2)',
              color: '#1e40af',
              fontWeight: 800,
            }}
          >
            LIVE
          </span>
        )}
        <style jsx global>{`
          @keyframes bulkPulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(1.3); }
          }
          @media (max-width: 640px) { .hide-bulk-mobile { display: none !important; } }
        `}</style>
      </button>
    );
  }

  if (variant === 'card') {
    return (
      <div
        className="card"
        style={{
          padding: 20,
          background: enabled
            ? 'linear-gradient(135deg, rgba(59,130,246,0.06), rgba(99,102,241,0.03))'
            : 'linear-gradient(135deg, rgba(239,68,68,0.05), rgba(220,38,38,0.02))',
          borderColor: enabled ? 'rgba(59,130,246,0.3)' : 'rgba(239,68,68,0.25)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, minWidth: 0, flex: 1 }}>
            <div style={{ fontSize: 36 }}>{enabled ? '📧' : '📪'}</div>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 800, color: enabled ? '#1e40af' : '#991b1b' }}>
                Bulk Worker {enabled ? 'ON' : 'OFF'}
              </div>
              <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginTop: 2 }}>
                {enabled
                  ? (isLive ? '● Emails bhej raha hai' : '● Waiting for queued emails')
                  : '● Emails nahi jaa rahi'}
              </div>
            </div>
          </div>

          <button
            onClick={toggle}
            disabled={busy || isLoading}
            style={{
              padding: '12px 24px',
              fontSize: 14,
              fontWeight: 800,
              borderRadius: 12,
              border: 'none',
              cursor: busy || isLoading ? 'not-allowed' : 'pointer',
              background: enabled
                ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
                : 'linear-gradient(135deg, #3b82f6 0%, #6366f1 100%)',
              color: '#fff',
              boxShadow: enabled
                ? '0 8px 20px -6px rgba(239,68,68,0.4)'
                : '0 8px 20px -6px rgba(59,130,246,0.4)',
              opacity: isLoading ? 0.6 : 1,
              flexShrink: 0,
            }}
          >
            {isLoading ? '⏳' : enabled ? '⏸️ TURN OFF' : '▶️ TURN ON'}
          </button>
        </div>

        {status && (
          <div style={{
            marginTop: 14, paddingTop: 14, borderTop: '1px solid var(--border)',
            display: 'flex', gap: 16, fontSize: 11, color: 'var(--fg-muted)', flexWrap: 'wrap',
          }}>
            <span>📬 Queued: <b style={{ color: 'var(--fg)' }}>{status.queued ?? 0}</b></span>
            <span>✅ Sent today: <b style={{ color: '#10b981' }}>{(status.sentToday ?? 0).toLocaleString()}</b></span>
            <span>🚀 Running: <b style={{ color: 'var(--fg)' }}>{status.runningCampaigns ?? 0}</b></span>
            <span>🕐 Last: <b style={{ color: 'var(--fg)' }}>
              {status.secondsSinceLastSend === null
                ? 'never'
                : status.secondsSinceLastSend < 60
                ? `${status.secondsSinceLastSend}s ago`
                : status.secondsSinceLastSend < 3600
                ? `${Math.floor(status.secondsSinceLastSend / 60)}m ago`
                : `${Math.floor(status.secondsSinceLastSend / 3600)}h ago`}
            </b></span>
          </div>
        )}
      </div>
    );
  }

  return (
    <button
      onClick={toggle}
      disabled={busy || isLoading}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        padding: '8px 16px', borderRadius: 10,
        border: '1px solid ' + (enabled ? 'rgba(59,130,246,0.3)' : 'rgba(239,68,68,0.3)'),
        background: enabled ? 'rgba(59,130,246,0.08)' : 'rgba(239,68,68,0.08)',
        color: enabled ? '#1e40af' : '#991b1b',
        fontWeight: 700, fontSize: 12,
        cursor: busy || isLoading ? 'not-allowed' : 'pointer',
      }}
    >
      <span style={{ width: 8, height: 8, borderRadius: '50%', background: enabled ? '#3b82f6' : '#ef4444' }} />
      📧 Bulk {enabled ? 'ON' : 'OFF'}
    </button>
  );
}
