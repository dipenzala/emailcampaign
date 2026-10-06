'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import WorkerToggle from '@/components/WorkerToggle';

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

      {/* Worker ON/OFF toggle — always visible */}
      <WorkerToggle variant="card" />

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
