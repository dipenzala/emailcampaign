'use client';
import { useState } from 'react';
import { toast } from './Toast';

export default function EmergencyStop() {
  const [stopping, setStopping] = useState(false);

  const stopAll = async () => {
    if (!confirm(
      '🛑 STOP ALL RUNNING CAMPAIGNS?\n\n' +
      '• All running campaigns will stop immediately\n' +
      '• All queued emails will be skipped\n' +
      '• No more emails will be sent\n\n' +
      'Continue?'
    )) return;

    setStopping(true);
    try {
      const r = await fetch('/api/campaigns/stop-all', { method: 'POST' });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`✅ Stopped ${j.campaigns_stopped} campaigns, ${j.recipients_skipped} recipients skipped`, 'success');
    } catch (e: any) {
      toast('❌ ' + e.message, 'error');
    }
    setStopping(false);
    window.location.reload();
  };

  return (
    <button
      onClick={stopAll}
      disabled={stopping}
      className="topbar-action"
      title="STOP ALL — Emergency stop all running campaigns"
      style={{
        background: 'rgba(239,68,68,0.15)',
        borderColor: 'rgba(239,68,68,0.4)',
        color: '#fca5a5',
        animation: 'pulse 2s ease-in-out infinite',
      }}
    >
      <span style={{ fontSize: 16 }}>{stopping ? '…' : '🛑'}</span>
    </button>
  );
}
