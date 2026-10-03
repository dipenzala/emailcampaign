#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🗑️  DELETE FEATURES + MOBILE RESPONSIVE"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. DELETE CAMPAIGN API
# ==========================================
echo "🗑️  [1/8] Creating delete APIs..."

mkdir -p 'app/api/campaigns/[id]'

cat > 'app/api/campaigns/[id]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET single campaign
export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: {
        recipients: {
          include: { contact: true },
          take: 200,
        },
      },
    });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    return NextResponse.json(campaign);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// DELETE campaign
export async function DELETE(_: Request, { params }: { params: { id: string } }) {
  try {
    await prisma.campaign.delete({ where: { id: params.id } });
    return NextResponse.json({ ok: true, message: 'Campaign deleted' });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/route.ts'
echo "   ✅ DELETE /api/campaigns/[id]"

# ==========================================
# 2. DELETE ALL CAMPAIGNS API
# ==========================================
mkdir -p app/api/campaigns/delete-all

cat > app/api/campaigns/delete-all/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { confirm } = await req.json();
    if (confirm !== 'DELETE ALL') {
      return NextResponse.json({ error: 'Confirmation required' }, { status: 400 });
    }

    // Count first
    const count = await prisma.campaign.count();

    // Delete all campaigns (cascades to recipients)
    await prisma.campaign.deleteMany({});

    return NextResponse.json({
      ok: true,
      deleted: count,
      message: `Deleted ${count} campaigns`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/delete-all/route.ts
echo "   ✅ POST /api/campaigns/delete-all"

# ==========================================
# 3. DELETE FAILED / OLD RECIPIENTS API
# ==========================================
mkdir -p app/api/campaigns/cleanup

cat > app/api/campaigns/cleanup/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { action } = await req.json();

    if (action === 'failed') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: { in: ['FAILED', 'BOUNCED'] } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Failed/bounced recipients removed' });
    }

    if (action === 'sent') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: 'SENT' },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Sent recipients removed' });
    }

    if (action === 'suppressed') {
      const r = await prisma.campaignRecipient.deleteMany({
        where: { status: 'SUPPRESSED' },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Suppressed recipients removed' });
    }

    if (action === 'empty-campaigns') {
      const empty = await prisma.campaign.findMany({
        where: { recipients: { none: {} } },
      });
      const r = await prisma.campaign.deleteMany({
        where: { id: { in: empty.map(c => c.id) } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Empty campaigns removed' });
    }

    if (action === 'old') {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const r = await prisma.campaign.deleteMany({
        where: { createdAt: { lt: thirtyDaysAgo } },
      });
      return NextResponse.json({ ok: true, deleted: r.count, message: 'Campaigns older than 30 days removed' });
    }

    return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/cleanup/route.ts
echo "   ✅ POST /api/campaigns/cleanup"

# ==========================================
# 4. DELETE SINGLE RECIPIENT API
# ==========================================
mkdir -p 'app/api/recipients/[id]'

cat > 'app/api/recipients/[id]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function DELETE(_: Request, { params }: { params: { id: string } }) {
  try {
    await prisma.campaignRecipient.delete({ where: { id: params.id } });
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/recipients/[id]/route.ts'
echo "   ✅ DELETE /api/recipients/[id]"

# ==========================================
# 5. NEW HISTORY PAGE (mobile responsive + delete)
# ==========================================
echo "📄 [5/8] Rewriting history page..."

mkdir -p app/history

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
  spamScore: number | null;
  createdAt: string;
  completedAt: string | null;
};

export default function HistoryPage() {
  const [list, setList] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [showCleanup, setShowCleanup] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/campaigns');
      const j = await r.json();
      setList(j);
    } catch { toast('Failed to load campaigns', 'error'); }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const filtered = list.filter(c => {
    if (filter !== 'ALL' && c.status !== filter) return false;
    if (search && !c.name.toLowerCase().includes(search.toLowerCase()) && !c.subject.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const toggleSelect = (id: string) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSelected(next);
  };

  const selectAll = () => {
    if (selected.size === filtered.length) {
      setSelected(new Set());
    } else {
      setSelected(new Set(filtered.map(c => c.id)));
    }
  };

  const deleteCampaign = async (id: string, name: string) => {
    if (!confirm(`Delete "${name}"?\n\nThis will remove the campaign and all its recipients.`)) return;
    setBusy(true);
    try {
      const r = await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      if (!r.ok) throw new Error('Delete failed');
      toast(`Deleted "${name}"`, 'success');
      await load();
      selected.delete(id);
      setSelected(new Set(selected));
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const deleteSelected = async () => {
    if (selected.size === 0) return;
    if (!confirm(`Delete ${selected.size} campaign(s)?`)) return;
    setBusy(true);
    try {
      for (const id of Array.from(selected)) {
        await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      }
      toast(`Deleted ${selected.size} campaigns`, 'success');
      setSelected(new Set());
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const deleteAll = async () => {
    const input = prompt('Type DELETE ALL (all caps) to confirm deleting EVERY campaign:');
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
      setSelected(new Set());
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const cleanup = async (action: string, label: string) => {
    if (!confirm(`${label}?`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/campaigns/cleanup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error);
      toast(`${label}: ${j.deleted} item(s) removed`, 'success');
      await load();
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

  const stats = {
    total: list.length,
    completed: list.filter(c => c.status === 'COMPLETED').length,
    running: list.filter(c => c.status === 'RUNNING').length,
    failed: list.filter(c => c.status === 'STOPPED' || c.failedCount > 0).length,
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">📜 Campaign History</h1>
          <p className="text-sm text-slate-400 mt-1">Manage, filter, and delete past campaigns</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New Campaign</Link>
          <button onClick={() => setShowCleanup(v => !v)} className="btn btn-ghost text-sm">
            🧹 Cleanup
          </button>
        </div>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard label="TOTAL" value={stats.total} color="text-white" />
        <StatCard label="COMPLETED" value={stats.completed} color="text-emerald-400" />
        <StatCard label="RUNNING" value={stats.running} color="text-blue-400" />
        <StatCard label="FAILED/STOPPED" value={stats.failed} color="text-red-400" />
      </div>

      {/* Cleanup panel */}
      {showCleanup && (
        <div className="card border-amber-500/30 animate-in">
          <h2 className="font-semibold mb-3">🧹 Cleanup Options</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
            <button onClick={() => cleanup('failed', 'Delete failed/bounced recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Failed + Bounced recipients
            </button>
            <button onClick={() => cleanup('sent', 'Delete sent recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Sent recipients
            </button>
            <button onClick={() => cleanup('suppressed', 'Delete suppressed recipients')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Suppressed recipients
            </button>
            <button onClick={() => cleanup('empty-campaigns', 'Delete empty campaigns')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Empty campaigns
            </button>
            <button onClick={() => cleanup('old', 'Delete 30+ day old campaigns')} className="btn btn-ghost text-xs justify-start" disabled={busy}>
              🗑️ Campaigns 30+ days old
            </button>
            <button onClick={deleteAll} className="btn btn-danger text-xs justify-start" disabled={busy}>
              ⚠️ Delete ALL campaigns
            </button>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="card !p-4 space-y-3">
        <div className="flex flex-col md:flex-row gap-3">
          <input
            className="input flex-1"
            placeholder="🔍 Search campaigns..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          {['ALL', 'RUNNING', 'COMPLETED', 'PAUSED', 'STOPPED', 'DRAFT'].map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`text-xs px-3 py-1.5 rounded-lg transition ${filter === f ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}
            >
              {f}
            </button>
          ))}
        </div>
        {selected.size > 0 && (
          <div className="flex items-center justify-between bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2">
            <span className="text-sm text-red-300">{selected.size} selected</span>
            <button onClick={deleteSelected} className="btn btn-danger text-xs" disabled={busy}>
              🗑️ Delete Selected
            </button>
          </div>
        )}
      </div>

      {/* List */}
      {loading ? (
        <div className="card text-center py-12 text-slate-500">Loading...</div>
      ) : filtered.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-3">📭</div>
          <p className="text-slate-400">No campaigns found</p>
          <Link href="/campaigns/new" className="btn btn-primary mt-4 inline-flex">+ Create your first campaign</Link>
        </div>
      ) : (
        <>
          {/* Desktop table */}
          <div className="hidden md:block card !p-0 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
                <tr>
                  <th className="p-3 w-8">
                    <input type="checkbox" checked={selected.size === filtered.length && filtered.length > 0} onChange={selectAll} className="w-4 h-4" />
                  </th>
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
                  <tr key={c.id} className="border-t border-white/5 hover:bg-white/[0.02] transition">
                    <td className="p-3">
                      <input type="checkbox" checked={selected.has(c.id)} onChange={() => toggleSelect(c.id)} className="w-4 h-4" />
                    </td>
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
                    <td className="p-3 text-xs text-slate-500">
                      {new Date(c.createdAt).toLocaleDateString()}
                      <div className="text-[10px]">{new Date(c.createdAt).toLocaleTimeString()}</div>
                    </td>
                    <td className="p-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Link href={`/campaigns/${c.id}`} className="text-xs px-2 py-1 rounded bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 transition">
                          Open
                        </Link>
                        <button
                          onClick={() => deleteCampaign(c.id, c.name)}
                          className="text-xs px-2 py-1 rounded bg-red-500/10 text-red-400 hover:bg-red-500/20 transition"
                          disabled={busy}
                        >
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="md:hidden space-y-3">
            {filtered.map(c => (
              <div key={c.id} className={`card !p-4 ${selected.has(c.id) ? 'ring-2 ring-violet-500' : ''}`}>
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="flex items-start gap-2 flex-1 min-w-0">
                    <input type="checkbox" checked={selected.has(c.id)} onChange={() => toggleSelect(c.id)} className="w-4 h-4 mt-1 flex-shrink-0" />
                    <div className="min-w-0 flex-1">
                      <div className="font-medium truncate">{c.name}</div>
                      <div className="text-xs text-slate-500 truncate">{c.subject}</div>
                    </div>
                  </div>
                  <span className={`text-xs font-semibold flex-shrink-0 ${getStatusColor(c.status)}`}>{c.status}</span>
                </div>
                <div className="grid grid-cols-3 gap-2 mb-3 text-center">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">TOTAL</div>
                    <div className="text-sm font-bold">{c.totalCount}</div>
                  </div>
                  <div className="bg-blue-500/10 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">SENT</div>
                    <div className="text-sm font-bold text-blue-400">{c.sentCount}</div>
                  </div>
                  <div className="bg-red-500/10 rounded-lg p-2">
                    <div className="text-[10px] text-slate-500">FAILED</div>
                    <div className="text-sm font-bold text-red-400">{c.failedCount}</div>
                  </div>
                </div>
                <div className="flex items-center justify-between text-xs text-slate-500 mb-3">
                  <span>{new Date(c.createdAt).toLocaleDateString()}</span>
                  <span>{new Date(c.createdAt).toLocaleTimeString()}</span>
                </div>
                <div className="flex gap-2">
                  <Link href={`/campaigns/${c.id}`} className="btn btn-ghost text-xs flex-1 justify-center">
                    Open
                  </Link>
                  <button
                    onClick={() => deleteCampaign(c.id, c.name)}
                    className="btn btn-danger text-xs flex-1 justify-center"
                    disabled={busy}
                  >
                    🗑️ Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="card !p-4">
      <div className="text-[10px] uppercase text-slate-500 tracking-wider">{label}</div>
      <div className={`text-2xl font-bold mt-1 ${color}`}>{value}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/history/page.tsx
echo "   ✅ History page with delete + mobile"

# ==========================================
# 6. UPDATE CAMPAIGN LIVE PAGE (mobile responsive)
# ==========================================
echo "📱 [6/8] Making campaign live page responsive..."

mkdir -p 'app/campaigns/[id]'

cat > 'app/campaigns/[id]/page.tsx' <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function CampaignLive() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params.id;
  const [s, setS] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);

  const loadStats = () => {
    fetch(`/api/campaigns/${id}/status`)
      .then(r => r.ok ? r.json() : null)
      .then(j => j && setS({ ...j.counts, status: j.campaign?.status, campaign: j.campaign }))
      .catch(() => {});
  };

  useEffect(() => {
    loadStats();
    const iv = setInterval(loadStats, 2000);
    return () => clearInterval(iv);
  }, [id]);

  const loadRecipients = () => {
    fetch(`/api/campaigns/${id}/recipients?status=${filter}`)
      .then(r => r.ok ? r.json() : [])
      .then(setRecipients)
      .catch(() => {});
  };

  useEffect(() => {
    loadRecipients();
    const iv = setInterval(loadRecipients, 3000);
    return () => clearInterval(iv);
  }, [id, filter]);

  const act = async (a: 'pause' | 'resume' | 'stop') => {
    if (a === 'stop' && !confirm('Stop campaign? Pending jobs removed.')) return;
    setBusy(true);
    try {
      await fetch(`/api/campaigns/${id}/${a}`, { method: 'POST' });
      toast(`Campaign ${a}d`, 'success');
      loadStats();
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const deleteCampaign = async () => {
    if (!confirm('Delete this campaign permanently?\n\nThis removes all recipients and history.')) return;
    setBusy(true);
    try {
      const r = await fetch(`/api/campaigns/${id}`, { method: 'DELETE' });
      if (!r.ok) throw new Error('Delete failed');
      toast('Campaign deleted', 'success');
      router.push('/history');
    } catch (e: any) { toast(e.message, 'error'); setBusy(false); }
  };

  const filtered = recipients.filter(r =>
    !search || (r.email || '').toLowerCase().includes(search.toLowerCase()) || (r.name || '').toLowerCase().includes(search.toLowerCase())
  );

  const progress = s?.progress ?? 0;

  return (
    <div className="space-y-4 md:space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold flex items-center gap-2">
            {s?.campaign?.name || 'Campaign'}
            <span className={`text-xs px-2 py-1 rounded-full ${
              s?.status === 'RUNNING' ? 'bg-blue-500/20 text-blue-400 animate-pulse' :
              s?.status === 'COMPLETED' ? 'bg-emerald-500/20 text-emerald-400' :
              s?.status === 'STOPPED' ? 'bg-slate-500/20 text-slate-400' :
              s?.status === 'PAUSED' ? 'bg-amber-500/20 text-amber-400' :
              'bg-slate-800 text-slate-400'
            }`}>{s?.status || '...'}</span>
          </h1>
          <p className="text-xs text-slate-500 mt-1">ID: {id.slice(-12)}</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          {s?.status === 'RUNNING' && <button onClick={() => act('pause')} disabled={busy} className="btn btn-ghost text-xs md:text-sm">⏸️ Pause</button>}
          {s?.status === 'PAUSED' && <button onClick={() => act('resume')} disabled={busy} className="btn btn-primary text-xs md:text-sm">▶️ Resume</button>}
          {s?.status !== 'COMPLETED' && s?.status !== 'STOPPED' && (
            <button onClick={() => act('stop')} disabled={busy} className="btn btn-danger text-xs md:text-sm">⏹️ Stop</button>
          )}
          <button onClick={deleteCampaign} disabled={busy} className="btn btn-danger text-xs md:text-sm">🗑️ Delete</button>
          <Link href="/history" className="btn btn-ghost text-xs md:text-sm">← Back</Link>
        </div>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2 md:gap-3">
        <KPI label="TOTAL" value={s?.total ?? 0} />
        <KPI label="SENT" value={s?.sent ?? 0} color="text-blue-400" />
        <KPI label="DELIVERED" value={s?.delivered ?? 0} color="text-emerald-400" />
        <KPI label="FAILED" value={s?.failed ?? 0} color="text-red-400" />
        <KPI label="BOUNCED" value={s?.bounced ?? 0} color="text-orange-400" />
        <KPI label="PENDING" value={s?.pending ?? 0} color="text-amber-400" />
        <KPI label="SUPPRESSED" value={s?.suppressed ?? 0} color="text-slate-400" />
      </div>

      {/* Progress */}
      <div className="card">
        <div className="flex justify-between text-sm mb-2">
          <span className="font-medium">Progress</span>
          <span className="text-lg font-bold">{progress.toFixed(1)}%</span>
        </div>
        <div className="w-full h-3 bg-slate-800 rounded-full overflow-hidden">
          <div className="h-full bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full transition-all duration-500"
            style={{ width: progress + '%' }} />
        </div>
      </div>

      {/* Recipients */}
      <div className="card">
        <div className="space-y-3 mb-3">
          <input
            className="input text-sm"
            placeholder="🔍 Search email or name..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          <div className="flex gap-2 flex-wrap">
            {['ALL', 'QUEUED', 'PROCESSING', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED', 'SUPPRESSED'].map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`text-xs px-2.5 py-1.5 rounded-lg transition ${filter === f ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>

        <div className="max-h-96 overflow-auto -mx-4 md:mx-0">
          {/* Desktop */}
          <table className="hidden md:table w-full text-xs">
            <thead className="text-slate-400 text-left sticky top-0 bg-slate-900">
              <tr>
                <th className="p-2">Email</th>
                <th>Name</th>
                <th>Status</th>
                <th>Error</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id} className="border-t border-slate-800">
                  <td className="p-2 font-mono">{r.email}</td>
                  <td>{r.name || '—'}</td>
                  <td className={statusColor(r.status)}>{r.status}</td>
                  <td className="text-slate-500 truncate max-w-xs">{r.error ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Mobile */}
          <div className="md:hidden divide-y divide-white/5">
            {filtered.map(r => (
              <div key={r.id} className="p-3">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <span className="font-mono text-xs truncate flex-1">{r.email}</span>
                  <span className={`text-xs font-semibold flex-shrink-0 ${statusColor(r.status)}`}>{r.status}</span>
                </div>
                {r.name && <div className="text-[11px] text-slate-500">{r.name}</div>}
                {r.error && <div className="text-[10px] text-red-400 truncate">{r.error}</div>}
              </div>
            ))}
            {filtered.length === 0 && (
              <div className="p-8 text-center text-slate-500 text-xs">No recipients</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function KPI({ label, value, color = '' }: { label: string; value: number; color?: string }) {
  return (
    <div className="bg-slate-950 border border-slate-800 rounded-lg p-2.5 md:p-3">
      <div className="text-[9px] md:text-[10px] uppercase text-slate-500 tracking-wider">{label}</div>
      <div className={`text-lg md:text-xl font-bold ${color}`}>{(value || 0).toLocaleString()}</div>
    </div>
  );
}

function statusColor(s: string) {
  return s === 'DELIVERED' ? 'text-emerald-400' :
    s === 'SENT' ? 'text-blue-400' :
    s === 'FAILED' || s === 'BOUNCED' ? 'text-red-400' :
    s === 'SUPPRESSED' ? 'text-slate-500' :
    s === 'PROCESSING' ? 'text-purple-400' :
    'text-amber-400';
}
EOF
sed -i 's/\r$//' 'app/campaigns/[id]/page.tsx'
echo "   ✅ Campaign live page mobile"

# ==========================================
# 7. MOBILE RESPONSIVE CSS
# ==========================================
echo "📱 [7/8] Adding extra mobile CSS..."

cat >> app/globals.css <<'EOF'

/* ============ EXTRA MOBILE ============ */
@media(max-width:768px){
  .card{ border-radius:16px; padding:16px; }
  .card:hover{ transform:none; }
  .btn{ padding:9px 16px; font-size:13px; border-radius:10px; }
  .input{ padding:10px 14px; font-size:14px; }
  .toast{ max-width:calc(100vw - 40px); font-size:12px; }
  .toast-container{ right:12px; top:70px; }
  h1{ font-size:1.5rem; }
}

@media(max-width:480px){
  .app-content{ padding:12px; }
  .topbar{ padding:8px 12px 8px 60px; min-height:56px; }
  .topbar-actions{ gap:6px; }
  .topbar-action{ width:32px; height:32px; }
  .toast-container{ right:8px; top:64px; }
}

/* ============ SCROLL ============ */
.mobile-scroll{
  overflow-x:auto;
  -webkit-overflow-scrolling:touch;
  scrollbar-width:none;
}
.mobile-scroll::-webkit-scrollbar{ display:none; }
EOF
sed -i 's/\r$//' app/globals.css
echo "   ✅"

# ==========================================
# 8. GIT PUSH
# ==========================================
echo ""
echo "🌿 [8/8] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: delete campaigns + cleanup APIs + mobile responsive history"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DELETE FEATURES DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 NEW FEATURES:"
echo "   ✓ Delete single campaign"
echo "   ✓ Delete selected campaigns (bulk)"
echo "   ✓ Delete ALL campaigns (typed confirmation)"
echo "   ✓ Cleanup: failed/bounced/sent/suppressed recipients"
echo "   ✓ Cleanup: empty campaigns, 30+ day old"
echo "   ✓ Search campaigns"
echo "   ✓ Filter by status"
echo "   ✓ Mobile responsive cards"
echo "   ✓ Touch-friendly UI"
echo ""
echo "📱 Mobile view:"
echo "   History: card layout"
echo "   Campaign live: mobile KPIs + list"
echo "   Sidebar: hamburger menu"
echo ""
echo "2-3 min me Vercel pe deploy hoga."
echo "==============================================="