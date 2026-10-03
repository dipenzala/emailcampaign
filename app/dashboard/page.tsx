'use client';
import { useEffect, useState } from 'react';
export default function DashboardHome() {
  const [senders, setSenders] = useState<any[]>([]);
  useEffect(() => { fetch('/api/senders').then(r => r.ok ? r.json() : []).then(setSenders).catch(() => {}); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Dashboard</h1>
      <p className="text-slate-400">Import contacts, paste HTML, launch your campaign.</p>
      <div className="grid md:grid-cols-4 gap-4">
        <a href="/senders" className="tilt card"><div className="text-3xl mb-2">🔐</div><h3 className="font-semibold">Senders</h3><p className="text-sm text-slate-400 mt-1">{senders.length} connected</p></a>
        <a href="/senders/rotation" className="tilt card"><div className="text-3xl mb-2">🔄</div><h3 className="font-semibold">Rotation</h3><p className="text-sm text-slate-400 mt-1">Batch settings</p></a>
        <a href="/anti-spam" className="tilt card"><div className="text-3xl mb-2">🛡️</div><h3 className="font-semibold">Anti-Spam</h3><p className="text-sm text-slate-400 mt-1">7-layer protection</p></a>
        <a href="/history" className="tilt card"><div className="text-3xl mb-2">📊</div><h3 className="font-semibold">History</h3><p className="text-sm text-slate-400 mt-1">Past campaigns</p></a>
      </div>
    </div>
  );
}
