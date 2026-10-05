#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎨 DESIGN CONSISTENCY FIX"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. FIX SENDERS PAGE — light theme
# ==========================================
echo "🎨 [1/4] Fixing Senders page (light theme)..."

mkdir -p app/senders

cat > app/senders/page.tsx <<'EOF'
'use client';
import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { toast } from '@/components/Toast';

function SendersInner() {
  const params = useSearchParams();
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/senders');
      const j = await r.json();
      setList(Array.isArray(j) ? j : []);
    } catch {}
    setLoading(false);
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  useEffect(() => {
    const c = params.get('connected');
    if (c) {
      toast(`✅ Connected ${c}`, 'success');
      window.history.replaceState({}, '', '/senders');
    }
  }, [params]);

  const connect = () => {
    if (!email || !email.includes('@')) { toast('Valid email daalo', 'error'); return; }
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email);
  };

  const disconnect = async (id: string, em: string) => {
    if (!confirm(`Disconnect ${em}?`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/disconnect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      if (!r.ok) throw new Error('Failed');
      toast(`Disconnected ${em}`, 'success');
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  const reconnect = (em: string) => {
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(em);
  };

  const connected = list.filter(s => s.status === 'CONNECTED').length;
  const totalCapacity = connected * 350;
  const totalUsed = list.reduce((sum, s) => sum + (s.sentToday || 0), 0);

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
        <p className="text-sm" style={{ color: 'var(--fg-muted)', marginTop: 4 }}>
          {connected}/{list.length} connected · Auto-refresh 5s
        </p>
      </div>

      {/* Usage Summary */}
      {connected > 0 && (
        <div className="card" style={{ background: 'linear-gradient(135deg, rgba(139,92,246,0.08), rgba(236,72,153,0.05))', borderColor: 'rgba(139,92,246,0.25)' }}>
          <div style={{ fontSize: 11, color: 'var(--fg-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 700, marginBottom: 12 }}>
            📊 24-Hour Usage
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 12 }}>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Capacity</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{totalCapacity}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Used</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#f59e0b' }}>{totalUsed}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>Remaining</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#10b981' }}>{totalCapacity - totalUsed}</div>
            </div>
          </div>
        </div>
      )}

      {/* Connect */}
      <div className="card">
        <h2 style={{ fontSize: 15, marginBottom: 12 }}>➕ Connect Gmail Account</h2>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <input
            className="input"
            style={{ flex: 1, minWidth: 200 }}
            placeholder="yourname@gmail.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
            type="email"
            onKeyDown={e => e.key === 'Enter' && connect()}
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email || busy}>
            Connect Google
          </button>
        </div>
        <div style={{ marginTop: 12, padding: 12, borderRadius: 10, background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.2)', fontSize: 12, color: '#1e40af' }}>
          ⚠️ Google screen pe <b>"Send email on your behalf"</b> ko <b>ALLOW</b> karo
        </div>
      </div>

      {/* Sender list */}
      {loading ? (
        <div className="card text-center" style={{ padding: 40, color: 'var(--fg-muted)' }}>Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center" style={{ padding: 48 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
          <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>Koi sender connect nahi hai</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {list.map(s => {
            const cap = s.dailyLimit || 350;
            const used = s.sentToday || 0;
            const remaining = Math.max(0, cap - used);
            const pct = Math.min(100, (used / cap) * 100);

            return (
              <div key={s.id} className="card" style={{ padding: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 12, flexWrap: 'wrap' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0, flex: 1 }}>
                    <div style={{
                      width: 44, height: 44, borderRadius: 12,
                      background: s.status === 'CONNECTED' ? 'linear-gradient(135deg, #10b981, #059669)' : 'linear-gradient(135deg, #ef4444, #dc2626)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: '#fff', fontSize: 18, flexShrink: 0,
                    }}>
                      {s.status === 'CONNECTED' ? '✓' : '✕'}
                    </div>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--fg)' }}>
                        {s.email}
                      </div>
                      <div style={{ fontSize: 11, color: s.status === 'CONNECTED' ? '#10b981' : '#dc2626', marginTop: 2, fontWeight: 600 }}>
                        ● {s.status}
                      </div>
                    </div>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginBottom: 12 }}>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Sent Today</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fg)', marginTop: 2 }}>{used}/{cap}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Remaining</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: remaining > 50 ? '#10b981' : '#f59e0b', marginTop: 2 }}>{remaining}</div>
                  </div>
                  <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', textTransform: 'uppercase', fontWeight: 600 }}>Limit</div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fg)', marginTop: 2 }}>{cap}</div>
                  </div>
                </div>

                <div style={{ width: '100%', height: 6, background: 'var(--bg-subtle)', borderRadius: 999, overflow: 'hidden', marginBottom: 12 }}>
                  <div style={{
                    height: '100%',
                    width: pct + '%',
                    background: pct >= 100 ? '#ef4444' : pct >= 70 ? '#f59e0b' : '#10b981',
                    transition: 'width .3s',
                  }} />
                </div>

                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    onClick={() => reconnect(s.email)}
                    disabled={busy}
                    className="btn btn-ghost"
                    style={{ flex: 1, fontSize: 13 }}
                  >
                    🔄 Reconnect
                  </button>
                  <button
                    onClick={() => disconnect(s.id, s.email)}
                    disabled={busy}
                    className="btn btn-danger"
                    style={{ flex: 1, fontSize: 13 }}
                  >
                    Disconnect
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function SendersPage() {
  return (
    <Suspense fallback={<div className="card text-center" style={{ padding: 40, color: 'var(--fg-muted)' }}>Loading...</div>}>
      <SendersInner />
    </Suspense>
  );
}
EOF
sed -i 's/\r$//' app/senders/page.tsx
echo "   ✅ Senders page — light theme"

# ==========================================
# 2. FIX LIVE DASHBOARD — consistent light cards
# ==========================================
echo ""
echo "🎨 [2/4] Fixing Live Dashboard (consistent light theme)..."

mkdir -p app/dashboard/live

cat > app/dashboard/live/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

type DetailsType = 'campaigns' | 'sent' | 'pending' | 'queued' | 'processing' | 'failed' | 'delivered' | 'bounced' | 'suppressed' | 'opened';

export default function LiveDashboard() {
  const [mounted, setMounted] = useState(false);
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0, opened: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [modal, setModal] = useState<DetailsType | null>(null);
  const [modalData, setModalData] = useState<any>(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [modalSearch, setModalSearch] = useState('');
  const [lastUpdate, setLastUpdate] = useState('--:--:--');

  useEffect(() => { setMounted(true); }, []);

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats || {});
        setSenders(j.senders || []);
        setCampaign(j.campaign);
        setActivity(j.activity || []);
        setLastUpdate(new Date().toLocaleTimeString());
      }
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, []);

  const openModal = async (type: DetailsType) => {
    setModal(type); setModalData(null); setModalSearch(''); setModalLoading(true);
    try {
      const r = await fetch(`/api/live/details?type=${type}&limit=500`);
      setModalData(await r.json());
    } catch (e: any) { setModalData({ ok: false, error: e.message }); }
    setModalLoading(false);
  };

  const closeModal = () => { setModal(null); setModalData(null); setModalSearch(''); };
  const progress = stats.total > 0 ? ((stats.total - stats.pending) / stats.total) * 100 : 0;

  return (
    <div className="animate-in">
      {/* Header */}
      <div className="page-header">
        <h1>
          <span>🔴 Live Dashboard</span>
          <span className="live-pill">LIVE</span>
        </h1>
        <p className="subtitle">Auto-refresh 3s · Last update {mounted ? lastUpdate : '--:--:--'}</p>
        <Link href="/campaigns/new" className="btn btn-primary" style={{ marginTop: 4 }}>+ New Campaign</Link>
      </div>

      <div className="page-hint">
        💡 Kisi bhi card pe click karo → detailed list dekho
      </div>

      {/* Big KPIs — all light cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12, marginBottom: 12 }}>
        <BigKPI label="TOTAL" value={stats.total ?? 0} color="#0f172a" hint="All campaigns" onClick={() => openModal('campaigns')} />
        <BigKPI label="SENT" value={stats.sent ?? 0} color="#3b82f6" hint="Who was sent" onClick={() => openModal('sent')} />
        <BigKPI label="PENDING" value={stats.pending ?? 0} color="#f59e0b" hint="Waiting" onClick={() => openModal('pending')} />
        <BigKPI label="FAILED" value={stats.failed ?? 0} color="#ef4444" hint="View failed" onClick={() => openModal('failed')} />
      </div>

      {/* Small KPIs — same light cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))', gap: 10, marginBottom: 20 }}>
        <SmallKPI label="QUEUED" value={stats.queued ?? 0} color="#f59e0b" onClick={() => openModal('queued')} />
        <SmallKPI label="PROCESSING" value={stats.processing ?? 0} color="#8b5cf6" onClick={() => openModal('processing')} />
        <SmallKPI label="DELIVERED" value={stats.delivered ?? 0} color="#10b981" onClick={() => openModal('delivered')} />
        <SmallKPI label="BOUNCED" value={stats.bounced ?? 0} color="#f97316" onClick={() => openModal('bounced')} />
        <SmallKPI label="SUPPRESSED" value={stats.suppressed ?? 0} color="#6b7280" onClick={() => openModal('suppressed')} />
        <SmallKPI label="OPENED" value={stats.opened ?? 0} color="#ec4899" onClick={() => openModal('opened')} />
      </div>

      {/* Progress */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontWeight: 600, fontSize: 14 }}>Overall Progress</span>
          <span style={{ fontSize: 22, fontWeight: 700 }}>{progress.toFixed(1)}%</span>
        </div>
        <div style={{ width: '100%', height: 10, background: 'var(--bg-subtle)', borderRadius: 999, overflow: 'hidden' }}>
          <div style={{
            height: '100%', width: progress + '%',
            background: 'linear-gradient(90deg, #8b5cf6, #3b82f6, #10b981)',
            transition: 'width .5s ease', borderRadius: 999,
          }} />
        </div>
      </div>

      {/* Senders summary */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 15, margin: 0 }}>👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)</h2>
          <Link href="/senders" style={{ fontSize: 12, color: '#8b5cf6', textDecoration: 'none', fontWeight: 600 }}>Manage →</Link>
        </div>
        {senders.length === 0 ? (
          <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>No senders connected</p>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 10 }}>
            {senders.slice(0, 6).map((s, i) => {
              const cap = s.dailyLimit || 350;
              const pct = Math.min(100, (s.sentToday / cap) * 100);
              return (
                <div key={i} style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 12 }}>
                  <div style={{ fontSize: 11, color: 'var(--fg-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginBottom: 6 }}>{s.email}</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                    <span style={{ fontSize: 10, color: s.status === 'CONNECTED' ? '#10b981' : '#ef4444', fontWeight: 600 }}>● {s.status}</span>
                    <span style={{ fontSize: 11, color: 'var(--fg-dim)', fontWeight: 600 }}>{s.sentToday}/{cap}</span>
                  </div>
                  <div style={{ width: '100%', height: 4, background: 'rgba(15,23,42,0.08)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: pct + '%', background: pct >= 100 ? '#ef4444' : pct >= 70 ? '#f59e0b' : '#10b981' }} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Latest campaign */}
      {campaign && (
        <div className="card" style={{ marginBottom: 16, cursor: 'pointer' }} onClick={() => openModal('campaigns')}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <h2 style={{ fontSize: 15, margin: 0 }}>📧 Latest Campaign</h2>
              <span style={{ fontSize: 11, padding: '4px 10px', borderRadius: 999, background: 'rgba(59,130,246,0.1)', color: '#1e40af', fontWeight: 600 }}>{campaign.status}</span>
            </div>
            <span style={{ fontSize: 12, color: '#8b5cf6', fontWeight: 600 }}>See all →</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 14 }}>
            <div><div style={{ fontSize: 11, color: 'var(--fg-muted)', marginBottom: 2, fontWeight: 600 }}>NAME</div><div style={{ fontSize: 13, fontWeight: 500 }}>{campaign.name}</div></div>
            <div><div style={{ fontSize: 11, color: 'var(--fg-muted)', marginBottom: 2, fontWeight: 600 }}>SUBJECT</div><div style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{campaign.subject}</div></div>
            <div><div style={{ fontSize: 11, color: 'var(--fg-muted)', marginBottom: 2, fontWeight: 600 }}>CREATED</div><div style={{ fontSize: 13 }}>{mounted ? new Date(campaign.createdAt).toLocaleString() : '...'}</div></div>
          </div>
        </div>
      )}

      {/* Activity */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 15, margin: 0 }}>📜 Live Activity</h2>
          <button onClick={() => openModal('sent')} style={{ fontSize: 12, color: '#8b5cf6', background: 'none', border: 'none', cursor: 'pointer', fontWeight: 600 }}>See all →</button>
        </div>
        <div style={{ background: '#f8fafc', border: '1px solid var(--border)', borderRadius: 12, padding: 16, maxHeight: 260, overflow: 'auto', fontFamily: 'monospace', fontSize: 12 }}>
          {activity.length === 0 ? (
            <div style={{ color: 'var(--fg-muted)' }}>Waiting for activity...</div>
          ) : (
            activity.map((l, i) => <div key={i} style={{ color: '#059669', padding: '3px 0' }}>{l}</div>)
          )}
        </div>
      </div>

      {modal && <Modal type={modal} data={modalData} loading={modalLoading} onClose={closeModal} search={modalSearch} setSearch={setModalSearch} />}
    </div>
  );
}

function BigKPI({ label, value, color, hint, onClick }: { label: string; value: number; color: string; hint?: string; onClick?: () => void }) {
  return (
    <button
      onClick={onClick}
      className="card"
      style={{
        textAlign: 'left',
        cursor: 'pointer',
        padding: 20,
        border: '1px solid var(--border)',
        transition: 'all .2s',
      }}
      onMouseEnter={e => { (e.currentTarget as HTMLElement).style.transform = 'translateY(-2px)'; (e.currentTarget as HTMLElement).style.boxShadow = '0 20px 60px -20px rgba(139,92,246,0.25)'; }}
      onMouseLeave={e => { (e.currentTarget as HTMLElement).style.transform = ''; (e.currentTarget as HTMLElement).style.boxShadow = ''; }}
    >
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.1em', color: 'var(--fg-muted)', fontWeight: 700 }}>{label}</div>
      <div style={{ fontSize: 32, fontWeight: 700, color, marginTop: 8, lineHeight: 1.1 }}>{value.toLocaleString()}</div>
      {hint && <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 4 }}>{hint}</div>}
    </button>
  );
}

function SmallKPI({ label, value, color, onClick }: { label: string; value: number; color: string; onClick?: () => void }) {
  return (
    <button
      onClick={onClick}
      className="card"
      style={{
        textAlign: 'left',
        cursor: 'pointer',
        padding: 14,
        border: '1px solid var(--border)',
        transition: 'all .2s',
      }}
      onMouseEnter={e => { (e.currentTarget as HTMLElement).style.transform = 'translateY(-2px)'; (e.currentTarget as HTMLElement).style.boxShadow = '0 20px 60px -20px rgba(139,92,246,0.25)'; }}
      onMouseLeave={e => { (e.currentTarget as HTMLElement).style.transform = ''; (e.currentTarget as HTMLElement).style.boxShadow = ''; }}
    >
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em', color: 'var(--fg-muted)', fontWeight: 700 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color, marginTop: 4, lineHeight: 1.1 }}>{value.toLocaleString()}</div>
    </button>
  );
}

const MODAL_TITLES: Record<DetailsType, string> = {
  campaigns: '📧 All Campaigns',
  sent: '✅ Sent Recipients',
  pending: '⏳ Pending Recipients',
  queued: '⏸️ Queued Recipients',
  processing: '🔄 Processing Recipients',
  failed: '❌ Failed Recipients',
  delivered: '📬 Delivered Recipients',
  bounced: '↩️ Bounced Recipients',
  suppressed: '🚫 Suppressed Recipients',
  opened: '👁️ Opened Emails',
};

function Modal({ type, data, loading, onClose, search, setSearch }: any) {
  const items: any[] = data?.items || [];
  const filtered = search
    ? items.filter((it: any) =>
        (it.email || '').toLowerCase().includes(search.toLowerCase()) ||
        (it.name || '').toLowerCase().includes(search.toLowerCase()) ||
        (it.subject || '').toLowerCase().includes(search.toLowerCase()))
    : items;

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);

  const statusColor = (s: string) => s === 'DELIVERED' ? '#10b981'
    : s === 'SENT' ? '#3b82f6'
    : s === 'FAILED' || s === 'BOUNCED' ? '#ef4444'
    : s === 'SUPPRESSED' ? '#6b7280'
    : s === 'PROCESSING' ? '#8b5cf6'
    : s === 'OPENED' ? '#ec4899'
    : '#f59e0b';

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-box" style={{ maxWidth: 900 }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, gap: 12, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>{MODAL_TITLES[type as DetailsType]}</h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {!loading && <span style={{ fontSize: 12, color: 'var(--fg-muted)' }}>{filtered.length} items</span>}
            <button onClick={onClose} className="btn btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }}>✕</button>
          </div>
        </div>

        <input className="input" style={{ fontSize: 13, marginBottom: 16 }} placeholder="🔍 Search..." value={search} onChange={e => setSearch(e.target.value)} />

        <div style={{ maxHeight: '60vh', overflow: 'auto' }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--fg-muted)' }}>Loading...</div>
          ) : !data?.ok ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#dc2626', fontSize: 13 }}>{data?.error || 'Failed to load'}</div>
          ) : type === 'campaigns' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {filtered.map((c: any) => (
                <Link key={c.id} href={`/campaigns/${c.id}`} onClick={onClose} style={{ textDecoration: 'none', color: 'inherit', background: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 12, padding: 14, display: 'block' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, marginBottom: 8, flexWrap: 'wrap' }}>
                    <div style={{ fontWeight: 600, fontSize: 14, flex: 1, minWidth: 0 }}>{c.name}</div>
                    <span style={{
                      fontSize: 11, padding: '3px 10px', borderRadius: 999, fontWeight: 600,
                      background: c.status === 'RUNNING' ? 'rgba(59,130,246,0.12)' : c.status === 'COMPLETED' ? 'rgba(16,185,129,0.12)' : 'rgba(100,116,139,0.12)',
                      color: c.status === 'RUNNING' ? '#1e40af' : c.status === 'COMPLETED' ? '#047857' : '#475569'
                    }}>{c.status}</span>
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginBottom: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.subject}</div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, fontSize: 12 }}>
                    <div><div style={{ fontSize: 10, color: 'var(--fg-dim)', fontWeight: 600 }}>TOTAL</div><div style={{ fontWeight: 600 }}>{c.totalCount}</div></div>
                    <div><div style={{ fontSize: 10, color: 'var(--fg-dim)', fontWeight: 600 }}>SENT</div><div style={{ fontWeight: 600, color: '#3b82f6' }}>{c.sentCount}</div></div>
                    <div><div style={{ fontSize: 10, color: 'var(--fg-dim)', fontWeight: 600 }}>FAILED</div><div style={{ fontWeight: 600, color: '#ef4444' }}>{c.failedCount}</div></div>
                    <div><div style={{ fontSize: 10, color: 'var(--fg-dim)', fontWeight: 600 }}>DATE</div><div style={{ fontWeight: 600, fontSize: 11 }}>{new Date(c.createdAt).toLocaleDateString()}</div></div>
                  </div>
                </Link>
              ))}
              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--fg-muted)' }}>No campaigns</div>}
            </div>
          ) : (
            <>
              <table style={{ width: '100%', fontSize: 12, borderCollapse: 'collapse' }} className="hide-mobile">
                <thead style={{ color: 'var(--fg-muted)', textAlign: 'left', background: 'var(--bg-subtle)' }}>
                  <tr>
                    <th style={{ padding: 10 }}>Email</th>
                    <th style={{ padding: 10 }}>Name</th>
                    <th style={{ padding: 10 }}>Status</th>
                    <th style={{ padding: 10 }}>Sender</th>
                    <th style={{ padding: 10 }}>Time</th>
                    <th style={{ padding: 10 }}>Error</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r: any) => (
                    <tr key={r.id} style={{ borderTop: '1px solid var(--border)' }}>
                      <td style={{ padding: 10, fontFamily: 'monospace', fontSize: 11 }}>{r.email}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{r.name || '—'}</td>
                      <td style={{ padding: 10, fontWeight: 700, color: statusColor(r.status) }}>{r.status}</td>
                      <td style={{ padding: 10, color: 'var(--fg-dim)', fontSize: 11 }}>{r.senderEmail || '—'}</td>
                      <td style={{ padding: 10, color: 'var(--fg-dim)', fontSize: 10 }}>{r.sentAt ? new Date(r.sentAt).toLocaleString() : '—'}</td>
                      <td style={{ padding: 10, color: '#dc2626', fontSize: 10, maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.error || ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="hide-desktop">
                {filtered.map((r: any) => (
                  <div key={r.id} style={{ padding: '12px 0', borderBottom: '1px solid var(--border)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontFamily: 'monospace', fontSize: 12, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.email}</span>
                      <span style={{ fontSize: 11, fontWeight: 700, color: statusColor(r.status) }}>{r.status}</span>
                    </div>
                    {r.name && <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>{r.name}</div>}
                    {r.senderEmail && <div style={{ fontSize: 10, color: 'var(--fg-dim)', marginTop: 2 }}>📤 {r.senderEmail}</div>}
                  </div>
                ))}
              </div>

              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--fg-muted)' }}>No items</div>}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/live/page.tsx
echo "   ✅ Live Dashboard — all cards light"

# ==========================================
# 3. FIX STATS API — TOTAL counter
# ==========================================
echo ""
echo "🔧 [3/4] Fixing stats API (TOTAL counter)..."

mkdir -p app/api/live/stats

cat > app/api/live/stats/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
    }

    // Get all status counts
    const groups = await prisma.campaignRecipient.groupBy({
      by: ['status'],
      _count: { _all: true },
    });

    const byStatus: Record<string, number> = {};
    groups.forEach(g => { byStatus[g.status] = g._count._all; });

    // Opened count
    let opened = 0;
    try {
      opened = await prisma.campaignRecipient.count({
        where: { openCount: { gt: 0 } } as any,
      });
    } catch { opened = 0; }

    const queued = byStatus.QUEUED ?? 0;
    const processing = byStatus.PROCESSING ?? 0;
    const sent = byStatus.SENT ?? 0;
    const delivered = byStatus.DELIVERED ?? 0;
    const failed = byStatus.FAILED ?? 0;
    const bounced = byStatus.BOUNCED ?? 0;
    const suppressed = byStatus.SUPPRESSED ?? 0;
    const pending = queued + processing;

    // TOTAL = all recipients ever
    const totalRecipients = await prisma.campaignRecipient.count();

    // Campaign count
    const totalCampaigns = await prisma.campaign.count();

    const senders = await prisma.senderAccount.findMany({
      orderBy: [{ status: 'asc' }, { sentToday: 'asc' }],
      select: {
        email: true, sentToday: true, dailyLimit: true, batchCount: true,
        status: true, isActive: true, reputationScore: true,
      },
    });

    const campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });

    const recent = await prisma.campaignRecipient.findMany({
      take: 15,
      orderBy: { sentAt: 'desc' },
      where: { sentAt: { not: null } },
      include: { contact: true },
    });

    const activity = recent.map(r => {
      const isOpened = ((r as any).openCount ?? 0) > 0;
      return `[${r.sentAt ? new Date(r.sentAt).toLocaleTimeString() : '--'}] ${isOpened ? '👁️' : '✅'} ${r.contact.email}`;
    });

    return NextResponse.json({
      ok: true,
      stats: {
        total: totalRecipients,
        totalCampaigns,
        sent,
        delivered,
        failed,
        bounced,
        suppressed,
        pending,
        queued,
        processing,
        opened,
      },
      senders,
      campaign,
      activity,
      ts: Date.now(),
    });
  } catch (err: any) {
    console.error('[live/stats]', err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/live/stats/route.ts
echo "   ✅ Stats API — TOTAL shows recipients count"

# ==========================================
# 4. GIT PUSH
# ==========================================
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Design fix: consistent light theme across all pages + TOTAL counter"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DESIGN FIXED"
echo "==============================================="
echo ""
echo "🎨 What changed:"
echo "   ✓ Senders page — light theme"
echo "   ✓ Live Dashboard — all cards light (no dark cards)"
echo "   ✓ TOTAL counter — shows recipient count"
echo "   ✓ Consistent colors across all pages"
echo "   ✓ Better usage display on Senders page"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "Hard refresh: Ctrl+Shift+R"
echo "==============================================="