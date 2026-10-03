'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function DashboardHome() {
  const [senders, setSenders] = useState<any[]>([]);
  useEffect(() => { fetch('/api/senders').then(r => r.ok ? r.json() : []).then(setSenders).catch(() => {}); }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Dashboard</h1>
          <p className="text-slate-400 mt-1">Import contacts, paste HTML, launch your campaign.</p>
        </div>
        <Link href="/campaigns/new" className="btn btn-primary text-base px-6 py-3">
          + New Campaign
        </Link>
      </div>

      {/* Big CTA */}
      <Link href="/campaigns/new" className="block tilt card !p-8 hover:shadow-2xl hover:shadow-violet-500/20 transition-all border-violet-500/30">
        <div className="flex items-center gap-6">
          <div className="text-6xl floaty">🚀</div>
          <div className="flex-1">
            <h2 className="text-2xl font-bold">Start a new campaign</h2>
            <p className="text-slate-400 mt-1">3 steps: upload contacts → paste HTML → launch</p>
          </div>
          <div className="text-3xl">→</div>
        </div>
      </Link>

      <div className="grid md:grid-cols-4 gap-4">
        <Link href="/senders" className="tilt card">
          <div className="text-3xl mb-2">🔐</div>
          <h3 className="font-semibold">Senders</h3>
          <p className="text-sm text-slate-400 mt-1">{senders.length} connected</p>
        </Link>
        <Link href="/senders/rotation" className="tilt card">
          <div className="text-3xl mb-2">🔄</div>
          <h3 className="font-semibold">Rotation</h3>
          <p className="text-sm text-slate-400 mt-1">Batch settings</p>
        </Link>
        <Link href="/anti-spam" className="tilt card">
          <div className="text-3xl mb-2">🛡️</div>
          <h3 className="font-semibold">Anti-Spam</h3>
          <p className="text-sm text-slate-400 mt-1">7-layer protection</p>
        </Link>
        <Link href="/history" className="tilt card">
          <div className="text-3xl mb-2">📊</div>
          <h3 className="font-semibold">History</h3>
          <p className="text-sm text-slate-400 mt-1">Past campaigns</p>
        </Link>
      </div>
    </div>
  );
}
