#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🛑 EMERGENCY STOP + FORCE DELETE"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. STOP ALL API
# ==========================================
echo "🛑 [1/6] Creating STOP ALL API..."

mkdir -p app/api/campaigns/stop-all

cat > app/api/campaigns/stop-all/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST() {
  try {
    // 1. Mark all RUNNING/PAUSED campaigns as STOPPED
    const stopped = await prisma.campaign.updateMany({
      where: { status: { in: ['RUNNING', 'PAUSED', 'DRAFT'] } },
      data: { status: 'STOPPED', completedAt: new Date() },
    });

    // 2. Mark all QUEUED/PROCESSING recipients as SKIPPED (won't be sent)
    const skipped = await prisma.campaignRecipient.updateMany({
      where: { status: { in: ['QUEUED', 'PROCESSING'] } },
      data: { status: 'SKIPPED', errorMessage: 'Stopped by user' },
    });

    return NextResponse.json({
      ok: true,
      campaigns_stopped: stopped.count,
      recipients_skipped: skipped.count,
      message: `Stopped ${stopped.count} campaigns, ${skipped.count} recipients skipped`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/stop-all/route.ts
echo "   ✅ POST /api/campaigns/stop-all"

# ==========================================
# 2. FORCE DELETE API (works even for RUNNING)
# ==========================================
echo "🗑️  [2/6] Updating Force Delete API..."

mkdir -p 'app/api/campaigns/[id]'

cat > 'app/api/campaigns/[id]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: { recipients: { include: { contact: true }, take: 500 } },
    });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(campaign);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// FORCE DELETE — works even if RUNNING/PROCESSING
export async function DELETE(_: Request, { params }: { params: { id: string } }) {
  try {
    // 1. Stop the campaign first
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'STOPPED' },
    }).catch(() => {});

    // 2. Delete all recipients first (explicit, to handle FK)
    await prisma.campaignRecipient.deleteMany({
      where: { campaignId: params.id },
    });

    // 3. Delete the campaign
    await prisma.campaign.delete({ where: { id: params.id } });

    return NextResponse.json({ ok: true, message: 'Campaign force-deleted' });
  } catch (err: any) {
    // If campaign not found, still return success
    if (err.code === 'P2025') {
      return NextResponse.json({ ok: true, message: 'Campaign already deleted' });
    }
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/route.ts'
echo "   ✅ DELETE works even for RUNNING"

# ==========================================
# 3. STOP ALL BUTTON COMPONENT
# ==========================================
echo "🎨 [3/6] Creating Stop All button component..."

mkdir -p components

cat > components/EmergencyStop.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' components/EmergencyStop.tsx
echo "   ✅"

# ==========================================
# 4. UPDATE TOPBAR WITH STOP ALL BUTTON
# ==========================================
echo "🎨 [4/6] Adding Stop All to topbar..."

cat > components/Topbar.tsx <<'EOF'
'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';
import EmergencyStop from './EmergencyStop';

const LABELS: Record<string, string> = {
  dashboard: 'Dashboard',
  live: 'Live',
  senders: 'Senders',
  rotation: 'Rotation',
  'anti-spam': 'Anti-Spam',
  history: 'Campaigns',
  campaigns: 'Campaigns',
  new: 'New',
  worker: 'Worker',
  settings: 'Settings',
  help: 'Help',
};

export default function Topbar({ sidebarCollapsed }: { sidebarCollapsed: boolean }) {
  const path = usePathname();
  const router = useRouter();
  const [showShortcuts, setShowShortcuts] = useState(false);

  const segments = path.split('/').filter(Boolean);

  const goBack = () => {
    if (typeof window !== 'undefined' && window.history.length > 1) {
      router.back();
    } else {
      router.push('/dashboard/live');
    }
  };

  const goHome = () => router.push('/dashboard/live');

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'h') { e.preventDefault(); router.push('/dashboard/live'); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') { e.preventDefault(); goBack(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); router.push('/campaigns/new'); }
      if (e.key === '?' && e.shiftKey) { setShowShortcuts(v => !v); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [router]);

  return (
    <>
      <header className="topbar">
        <button className="topbar-back" onClick={goBack} title="Back (Ctrl+B)">
          <span style={{ fontSize: 16 }}>←</span>
        </button>
        <button className="topbar-home" onClick={goHome} title="Home (Ctrl+H)">
          <span style={{ fontSize: 16 }}>⌂</span>
        </button>

        <nav className="topbar-breadcrumbs">
          <Link href="/dashboard/live">Home</Link>
          {segments.map((seg, i) => {
            const isLast = i === segments.length - 1;
            const label = LABELS[seg] || seg;
            return (
              <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span className="sep">/</span>
                {isLast ? <span className="current">{label}</span> : <Link href={'/' + segments.slice(0, i + 1).join('/')}>{label}</Link>}
              </span>
            );
          })}
        </nav>

        <div className="topbar-actions">
          <EmergencyStop />
          <Link href="/campaigns/new" className="topbar-action" title="New Campaign (Ctrl+K)">
            <span style={{ fontSize: 16 }}>+</span>
          </Link>
          <button className="topbar-action" onClick={() => setShowShortcuts(true)} title="Shortcuts (?)">
            <span style={{ fontSize: 14 }}>?</span>
          </button>
          <div className="topbar-user" onClick={() => router.push('/settings')}>
            <div className="topbar-avatar">D</div>
            <span style={{ fontSize: 13, color: '#e2e8f0' }} className="hidden md:inline">Dipen</span>
          </div>
        </div>
      </header>

      {showShortcuts && (
        <div onClick={() => setShowShortcuts(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
          <div onClick={e => e.stopPropagation()} className="card" style={{ maxWidth: 500, width: '100%' }}>
            <h2 style={{ marginBottom: 16, fontSize: 20 }}>⌨️ Keyboard Shortcuts</h2>
            {[
              ['Ctrl + H', 'Home / Live Dashboard'],
              ['Ctrl + B', 'Go Back'],
              ['Ctrl + K', 'New Campaign'],
              ['?', 'Show this dialog'],
            ].map(([key, desc]) => (
              <div key={key} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <code style={{ background: 'rgba(255,255,255,0.08)', padding: '3px 10px', borderRadius: 6, fontSize: 12, color: '#e9d5ff' }}>{key}</code>
                <span style={{ color: '#cbd5e1', fontSize: 13 }}>{desc}</span>
              </div>
            ))}
            <button className="btn btn-primary" onClick={() => setShowShortcuts(false)} style={{ marginTop: 16, width: '100%' }}>Got it</button>
          </div>
        </div>
      )}
    </>
  );
}
EOF
sed -i 's/\r$//' components/Topbar.tsx
echo "   ✅"

# ==========================================
# 5. UPDATE HISTORY PAGE WITH BIG STOP BUTTON
# ==========================================
echo "📄 [5/6] Updating history page..."

cat > app/history/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

type Campaign = {
  id: string;
  name: string;
  subject: string;
  status: string;
  totalCount: number;
  sentCount: number;
  failedCount: number;
  createdAt: string;
};

export default function HistoryPage() {
  const [list, setList] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [stopBusy, setStopBusy] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/campaigns');
      const j = await r.json();
      setList(j);
    } catch { toast('Failed to load', 'error'); }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const filtered = list.filter(c => {
    if (filter !== 'ALL' && c.status !== filter) return false;
    if (search && !c.name.toLowerCase().includes(search.toLowerCase()) && !c.subject.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const stopAll = async () => {
    if (!confirm('🛑 STOP ALL RUNNING CAMPAIGNS?\n\nAll queued emails will be skipped immediately.')) return;
    setStopBusy(true);
    try {
      const r = await fetch('/api/campaigns/stop-all', { method: 'POST' });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`✅ Stopped ${j.campaigns_stopped} campaigns`, 'success');
      await load();
    } catch (e: any) { toast('❌ ' + e.message, 'error'); }
    setStopBusy(false);
  };

  const deleteCampaign = async (id: string, name: string) => {
    if (!confirm(`🗑️  Delete "${name}" permanently?\n\nAll recipients and history removed.`)) return;
    setBusy(true);
    try {
      const r = await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      if (!r.ok) throw new Error('Delete failed');
      toast(`Deleted "${name}"`, 'success');
      setList(list.filter(c => c.id !== id));
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const deleteAll = async () => {
    const input = prompt('Type DELETE ALL (uppercase) to confirm deleting EVERY campaign:');
    if (input !== 'DELETE ALL') { toast('Cancelled', 'info'); return; }
    setBusy(true);
    try {
      const r = await fetch('/api/campaigns/delete-all', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ confirm: 'DELETE ALL' }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`Deleted ${j.deleted} campaigns`, 'success');
      setList([]);
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const getStatusColor = (s: string) => {
    if (s === 'COMPLETED') return 'text-emerald-400';
    if (s === 'RUNNING') return 'text-blue-400';
    if (s === 'PAUSED') return 'text-amber-400';
    if (s === 'STOPPED') return 'text-slate-400';
    if (s === 'DRAFT') return 'text-purple-400';
    return 'text-slate-400';
  };

  const running = list.filter(c => c.status === 'RUNNING').length;

  return (
    <div className="space-y-4 md:space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">📜 Campaign History</h1>
          <p className="text-xs md:text-sm text-slate-400 mt-1">
            {list.length} total · {running} running
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <button
            onClick={stopAll}
            disabled={stopBusy || running === 0}
            className="btn text-sm"
            style={{
              background: running > 0 ? 'linear-gradient(135deg,#ef4444,#dc2626)' : 'rgba(255,255,255,0.05)',
              color: '#fff',
              border: '1px solid rgba(239,68,68,0.4)',
            }}
          >
            {stopBusy ? '⏸️ Stopping...' : `🛑 STOP ALL (${running})`}
          </button>
          <button onClick={deleteAll} disabled={busy || list.length === 0} className="btn btn-danger text-sm">
            🗑️ Delete All
          </button>
          <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New</Link>
        </div>
      </div>

      {/* Running alert */}
      {running > 0 && (
        <div className="card border-red-500/40 bg-red-500/10 animate-pulse !p-4">
          <div className="flex items-center gap-3">
            <div className="text-2xl">🔴</div>
            <div className="flex-1">
              <div className="font-semibold text-red-300">{running} campaign(s) currently running</div>
              <div className="text-xs text-red-200/70">Click STOP ALL to halt immediately</div>
            </div>
            <button onClick={stopAll} disabled={stopBusy} className="btn btn-danger text-xs">
              🛑 STOP NOW
            </button>
          </div>
        </div>
      )}

      {/* Search + Filter */}
      <div className="card !p-4 space-y-3">
        <input className="input text-sm" placeholder="🔍 Search..." value={search} onChange={e => setSearch(e.target.value)} />
        <div className="flex flex-wrap gap-2">
          {['ALL', 'RUNNING', 'COMPLETED', 'PAUSED', 'STOPPED', 'DRAFT'].map(f => (
            <button key={f} onClick={() => setFilter(f)}
              className={`text-xs px-3 py-1.5 rounded-lg transition ${filter === f ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}>
              {f}
            </button>
          ))}
        </div>
      </div>

      {/* List */}
      {loading ? (
        <div className="card text-center py-12 text-slate-500">Loading...</div>
      ) : filtered.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-3">📭</div>
          <p className="text-slate-400">No campaigns</p>
          <Link href="/campaigns/new" className="btn btn-primary mt-4 inline-flex">+ New Campaign</Link>
        </div>
      ) : (
        <>
          {/* Desktop */}
          <div className="hidden md:block card !p-0 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
                <tr>
                  <th className="p-3">Campaign</th>
                  <th className="p-3 text-center">Total</th>
                  <th className="p-3 text-center">Sent</th>
                  <th className="p-3 text-center">Failed</th>
                  <th className="p-3 text-center">Status</th>
                  <th className="p-3">Created</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(c => (
                  <tr key={c.id} className="border-t border-white/5 hover:bg-white/[0.02]">
                    <td className="p-3">
                      <div className="font-medium">{c.name}</div>
                      <div className="text-xs text-slate-500 truncate max-w-xs">{c.subject}</div>
                    </td>
                    <td className="p-3 text-center">{c.totalCount}</td>
                    <td className="p-3 text-center text-blue-400">{c.sentCount}</td>
                    <td className="p-3 text-center text-red-400">{c.failedCount}</td>
                    <td className="p-3 text-center">
                      <span className={`text-xs font-semibold ${getStatusColor(c.status)}`}>{c.status}</span>
                    </td>
                    <td className="p-3 text-xs text-slate-500">{new Date(c.createdAt).toLocaleString()}</td>
                    <td className="p-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Link href={`/campaigns/${c.id}`} className="text-xs px-2 py-1 rounded bg-blue-500/10 text-blue-400 hover:bg-blue-500/20">Open</Link>
                        <button onClick={() => deleteCampaign(c.id, c.name)} disabled={busy} className="text-xs px-2 py-1 rounded bg-red-500/10 text-red-400 hover:bg-red-500/20">🗑️</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile */}
          <div className="md:hidden space-y-3">
            {filtered.map(c => (
              <div key={c.id} className="card !p-4">
                <div className="flex items-start justify-between gap-2 mb-3">
                  <div className="min-w-0 flex-1">
                    <div className="font-medium truncate">{c.name}</div>
                    <div className="text-xs text-slate-500 truncate">{c.subject}</div>
                  </div>
                  <span className={`text-xs font-semibold flex-shrink-0 ${getStatusColor(c.status)}`}>{c.status}</span>
                </div>
                <div className="grid grid-cols-3 gap-2 mb-3 text-center text-xs">
                  <div className="bg-white/5 rounded p-2">
                    <div className="text-[10px] text-slate-500">TOTAL</div>
                    <div className="font-bold">{c.totalCount}</div>
                  </div>
                  <div className="bg-blue-500/10 rounded p-2">
                    <div className="text-[10px] text-slate-500">SENT</div>
                    <div className="font-bold text-blue-400">{c.sentCount}</div>
                  </div>
                  <div className="bg-red-500/10 rounded p-2">
                    <div className="text-[10px] text-slate-500">FAILED</div>
                    <div className="font-bold text-red-400">{c.failedCount}</div>
                  </div>
                </div>
                <div className="text-[10px] text-slate-500 mb-3">{new Date(c.createdAt).toLocaleString()}</div>
                <div className="flex gap-2">
                  <Link href={`/campaigns/${c.id}`} className="btn btn-ghost text-xs flex-1 justify-center">Open</Link>
                  <button onClick={() => deleteCampaign(c.id, c.name)} disabled={busy} className="btn btn-danger text-xs flex-1 justify-center">🗑️ Delete</button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
EOF
sed -i 's/\r$//' app/history/page.tsx
echo "   ✅"

# ==========================================
# 6. PULSE ANIMATION + GIT PUSH
# ==========================================
cat >> app/globals.css <<'EOF'

@keyframes pulse {
  0%,100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.7; transform: scale(1.05); }
}
EOF
sed -i 's/\r$//' app/globals.css

echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: emergency STOP ALL + force delete anytime"
git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ EMERGENCY STOP DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 NEW FEATURES:"
echo ""
echo "  🛑 TOPBAR: Red STOP button (always visible)"
echo "     → Click → confirm → all campaigns stop"
echo ""
echo "  🛑 HISTORY PAGE: Big red STOP ALL button"
echo "     → Shows count of running campaigns"
echo "     → Pulse alert banner if running"
echo ""
echo "  🗑️  Delete ANY campaign (even RUNNING)"
echo "     → Force delete works in any state"
echo "     → Also deletes from DB"
echo ""
echo "  🗑️  Delete All Campaigns"
echo "     → Type DELETE ALL to confirm"
echo ""
echo "  ⚡ Instant stop:"
echo "     → RUNNING → STOPPED"
echo "     → QUEUED → SKIPPED"
echo "     → Worker stops immediately on next poll (2-5 sec)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "🎯 TEST:"
echo "   https://emailcampaign-ten.vercel.app/history"
echo "   → Big red STOP ALL button"
echo "==============================================="