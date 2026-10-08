'use client';
import { useEffect, useRef, useState } from 'react';

type Props = {
  campaignId: string;
  enabled: boolean;
  onComplete?: () => void;
};

/**
 * Auto-Send Loop
 * Calls /api/scheduler repeatedly until queue is empty.
 * No GitHub Actions needed — works 100% from browser.
 */
export default function AutoSendLoop({ campaignId, enabled, onComplete }: Props) {
  const [running, setRunning] = useState(false);
  const [sent, setSent] = useState(0);
  const [failed, setFailed] = useState(0);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [lastError, setLastError] = useState('');
  const [active, setActive] = useState(false);
  const runningRef = useRef(false);

  useEffect(() => {
    if (!enabled) return;
    if (runningRef.current) return;

    runningRef.current = true;
    setRunning(true);
    setActive(true);

    const loop = async () => {
      while (runningRef.current) {
        try {
          const r = await fetch('/api/scheduler', { method: 'POST' });
          const j = await r.json();

          if (!j.ok) {
            setLastError(j.error || 'Unknown error');
            break;
          }

          setSent(s => s + (j.sent || 0));
          setFailed(s => s + (j.failed || 0));
          setRemaining(j.stillQueued ?? 0);

          // Done?
          if ((j.stillQueued ?? 0) === 0) {
            setRunning(false);
            setActive(false);
            runningRef.current = false;
            onComplete?.();
            return;
          }
        } catch (e: any) {
          setLastError(e.message || 'Fetch failed');
          await new Promise(r => setTimeout(r, 3000));
        }
      }
      setRunning(false);
      setActive(false);
    };

    loop();

    return () => {
      runningRef.current = false;
    };
  }, [enabled, campaignId, onComplete]);

  if (!active && sent === 0 && failed === 0) return null;

  return (
    <div className="card" style={{
      background: running
        ? 'linear-gradient(135deg, rgba(16,185,129,0.08), rgba(5,150,105,0.04))'
        : 'linear-gradient(135deg, rgba(59,130,246,0.06), rgba(99,102,241,0.03))',
      borderColor: running ? 'rgba(16,185,129,0.4)' : 'rgba(59,130,246,0.3)',
      padding: 20,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div style={{ fontSize: 32 }}>{running ? '🟢' : '✅'}</div>
        <div style={{ flex: 1, minWidth: 200 }}>
          <div style={{ fontWeight: 800, fontSize: 15, color: running ? '#065f46' : '#1e40af' }}>
            {running ? 'AUTO-SENDING ACTIVE' : 'Auto-send complete'}
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginTop: 2 }}>
            Sent: <b style={{ color: '#10b981' }}>{sent}</b> · Failed: <b style={{ color: '#ef4444' }}>{failed}</b>
            {remaining !== null && <> · Remaining: <b>{remaining}</b></>}
          </div>
          {lastError && (
            <div style={{ fontSize: 11, color: '#dc2626', marginTop: 4 }}>
              ⚠️ {lastError}
            </div>
          )}
        </div>
        {running && (
          <div style={{ fontSize: 11, fontWeight: 700, color: '#059669' }}>
            ● LIVE
          </div>
        )}
      </div>
    </div>
  );
}
