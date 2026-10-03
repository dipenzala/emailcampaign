'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

type DetailsType = 'campaigns' | 'sent' | 'pending' | 'queued' | 'processing' | 'failed' | 'delivered' | 'bounced' | 'suppressed';

export default function LiveDashboard() {
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0, opened: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [modal, setModal] = useState<DetailsType | null>(null);
  const [modalData, setModalData] = useState<any>(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [modalSearch, setModalSearch] = useState('');

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats); setSenders(j.senders || []);
        setCampaign(j.campaign); setActivity(j.activity || []);
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
    <div className="animate-in" style={{ paddingTop: 8 }}>
      {/* Page header — centered layout */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: 32, gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', justifyContent: 'center' }}>
          <h1 style={{ margin: 0 }}>🔴 Live Dashboard</h1>
          <span style={{
            fontSize: 11, padding: '5px 12px', borderRadius: 999,
            background: 'rgba(16,185,129,0.15)', color: '#34d399',
            border: '1px solid rgba(16,185,129,0.3)',
            fontWeight: 600, letterSpacing: '0.05em',
            animation: 'pulse 2s ease-in-out infinite'
          }}>● LIVE</span>
        </div>
        <p style={{ color: '#64748b', fontSize: 13, margin: 0 }}>
          Auto-refresh every 3s · Last update {new Date().toLocaleTimeString()}
        </p>
        <Link href="/campaigns/new" className="btn btn-primary" style={{ marginTop: 8 }}>
          + New Campaign
        </Link>
      </div>

      <div style={{ fontSize: 12, color: '#64748b', textAlign: 'center', marginBottom: 20 }}>
        💡 Kisi bhi card pe click karo → detailed list dekho
      </div>

      {/* Big KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
        <KPI label="TOTAL" value={stats.total} color="text-white" big onClick={() => openModal('campaigns')} hint="All campaigns" />
        <KPI label="SENT" value={stats.sent} color="text-blue-400" big onClick={() => openModal('sent')} hint="Who was sent" />
        <KPI label="PENDING" value={stats.pending} color="text-amber-400" big onClick={() => openModal('pending')} hint="Waiting" />
        <KPI label="FAILED" value={stats.failed} color="text-red-400" big onClick={() => openModal('failed')} hint="View failed" />
      </div>

      <div className="grid grid-cols-3 md:grid-cols-6 gap-2 mb-6">
        <KPI label="QUEUED" value={stats.queued} color="text-yellow-400" onClick={() => openModal('queued')} />
        <KPI label="PROCESSING" value={stats.processing} color="text-purple-400" onClick={() => openModal('processing')} />
        <KPI label="DELIVERED" value={stats.delivered} color="text-emerald-400" onClick={() => openModal('delivered')} />
        <KPI label="BOUNCED" value={stats.bounced} color="text-orange-400" onClick={() => openModal('bounced')} />
        <KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" onClick={() => openModal('suppressed')} />
        <KPI label="OPENED" value={stats.opened || 0} color="text-pink-400" onClick={() => openModal('opened')} />
      </div>

      {/* Progress */}
      <div className="card mb-6">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontWeight: 500, fontSize: 14 }}>Overall Progress</span>
          <span style={{ fontSize: 20, fontWeight: 700 }}>{progress.toFixed(1)}%</span>
        </div>
        <div style={{ width: '100%', height: 12, background: 'rgba(30,41,59,0.8)', borderRadius: 999, overflow: 'hidden' }}>
          <div style={{
            height: '100%', width: progress + '%',
            background: 'linear-gradient(90deg, #8b5cf6, #3b82f6, #10b981)',
            transition: 'width .5s ease', borderRadius: 999,
            boxShadow: '0 0 20px rgba(139,92,246,0.5)'
          }} />
        </div>
      </div>

      {/* Senders */}
      <div className="card mb-6">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 16, margin: 0 }}>👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)</h2>
          <Link href="/senders" style={{ fontSize: 12, color: '#a78bfa', textDecoration: 'none' }}>Manage →</Link>
        </div>
        {senders.length === 0 ? (
          <p style={{ fontSize: 13, color: '#64748b', margin: 0 }}>No senders connected</p>
        ) : (
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {senders.map((s, i) => {
              const usage = s.dailyLimit > 0 ? (s.sentToday / s.dailyLimit) * 100 : 0;
              return (
                <div key={i} style={{ background: 'rgba(2,6,23,0.6)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 14 }}>
                  <div style={{ fontSize: 12, color: '#94a3b8', marginBottom: 8, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.email}</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                    <span style={{ fontSize: 11, color: s.status === 'CONNECTED' ? '#34d399' : '#f87171', fontWeight: 500 }}>● {s.status}</span>
                    <span style={{ fontSize: 11, color: '#64748b' }}>{s.sentToday}/{s.dailyLimit}</span>
                  </div>
                  <div style={{ width: '100%', height: 4, background: 'rgba(30,41,59,0.8)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{
                      height: '100%', width: Math.min(100, usage) + '%',
                      background: usage >= 100 ? '#ef4444' : usage >= 70 ? '#f59e0b' : '#10b981'
                    }} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {campaign && (
        <div className="card mb-6" style={{ cursor: 'pointer' }} onClick={() => openModal('campaigns')}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <h2 style={{ fontSize: 16, margin: 0 }}>📧 Latest Campaign</h2>
              <span style={{
                fontSize: 11, padding: '4px 10px', borderRadius: 999,
                background: 'rgba(59,130,246,0.15)', color: '#60a5fa',
                fontWeight: 600
              }}>{campaign.status}</span>
            </div>
            <span style={{ fontSize: 12, color: '#a78bfa' }}>See all →</span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>NAME</div><div style={{ fontSize: 14, fontWeight: 500 }}>{campaign.name}</div></div>
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>SUBJECT</div><div style={{ fontSize: 14, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{campaign.subject}</div></div>
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>CREATED</div><div style={{ fontSize: 13 }}>{new Date(campaign.createdAt).toLocaleString()}</div></div>
          </div>
        </div>
      )}

      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 16, margin: 0 }}>📜 Live Activity</h2>
          <button onClick={() => openModal('sent')} style={{ fontSize: 12, color: '#a78bfa', background: 'none', border: 'none', cursor: 'pointer' }}>See all →</button>
        </div>
        <div style={{ background: '#000', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 16, maxHeight: 260, overflow: 'auto', fontFamily: 'monospace', fontSize: 12 }}>
          {activity.length === 0 ? (
            <div style={{ color: '#64748b' }}>Waiting for activity...</div>
          ) : (
            activity.map((l, i) => <div key={i} style={{ color: '#6ee7b7', padding: '3px 0' }}>{l}</div>)
          )}
        </div>
      </div>

      {modal && <Modal type={modal} data={modalData} loading={modalLoading} onClose={closeModal} search={modalSearch} setSearch={setModalSearch} />}
    </div>
  );
}

function KPI({ label, value, color, big = false, onClick, hint }: { label: string; value: number; color: string; big?: boolean; onClick?: () => void; hint?: string }) {
  return (
    <button
      onClick={onClick}
      disabled={!onClick}
      className={`${big ? 'card !p-5' : 'bg-slate-950 border border-slate-800 rounded-lg p-3'} text-left w-full transition-all ${onClick ? 'hover:scale-[1.02] hover:border-violet-500/40 cursor-pointer active:scale-[0.98]' : ''} group`}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: big ? 11 : 9, textTransform: 'uppercase', letterSpacing: '0.1em', color: '#64748b', fontWeight: 600 }}>{label}</div>
        {onClick && <span style={{ fontSize: 11, color: '#a78bfa', opacity: 0 }} className="group-hover:opacity-100">→</span>}
      </div>
      <div className={`${big ? 'text-3xl md:text-4xl' : 'text-lg md:text-xl'} font-bold mt-2 ${color}`}>{(value || 0).toLocaleString()}</div>
      {hint && <div style={{ fontSize: 10, color: '#475569', marginTop: 4 }}>{hint}</div>}
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

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-box" style={{ maxWidth: 900 }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, gap: 12, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>{MODAL_TITLES[type as DetailsType]}</h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {!loading && <span style={{ fontSize: 12, color: '#64748b' }}>{filtered.length} items</span>}
            <button onClick={onClose} className="btn btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }}>✕</button>
          </div>
        </div>

        <input className="input" style={{ fontSize: 13, marginBottom: 16 }} placeholder="🔍 Search..." value={search} onChange={e => setSearch(e.target.value)} />

        <div style={{ maxHeight: '60vh', overflow: 'auto' }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>Loading...</div>
          ) : !data?.ok ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#f87171', fontSize: 13 }}>{data?.error || 'Failed to load'}</div>
          ) : type === 'campaigns' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {filtered.map((c: any) => (
                <Link key={c.id} href={`/campaigns/${c.id}`} onClick={onClose} style={{ textDecoration: 'none', color: 'inherit', background: 'rgba(2,6,23,0.6)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 14, display: 'block', transition: 'border .2s' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, marginBottom: 8, flexWrap: 'wrap' }}>
                    <div style={{ fontWeight: 500, fontSize: 14, flex: 1, minWidth: 0 }}>{c.name}</div>
                    <span style={{
                      fontSize: 11, padding: '3px 10px', borderRadius: 999, fontWeight: 600,
                      background: c.status === 'RUNNING' ? 'rgba(59,130,246,0.15)' : c.status === 'COMPLETED' ? 'rgba(16,185,129,0.15)' : 'rgba(100,116,139,0.15)',
                      color: c.status === 'RUNNING' ? '#60a5fa' : c.status === 'COMPLETED' ? '#34d399' : '#94a3b8'
                    }}>{c.status}</span>
                  </div>
                  <div style={{ fontSize: 12, color: '#64748b', marginBottom: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.subject}</div>
                  <div className="grid grid-cols-4 gap-3" style={{ fontSize: 12 }}>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>TOTAL</div><div style={{ fontWeight: 600 }}>{c.totalCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>SENT</div><div style={{ fontWeight: 600, color: '#60a5fa' }}>{c.sentCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>FAILED</div><div style={{ fontWeight: 600, color: '#f87171' }}>{c.failedCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>DATE</div><div style={{ fontWeight: 600, fontSize: 11 }}>{new Date(c.createdAt).toLocaleDateString()}</div></div>
                  </div>
                </Link>
              ))}
              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>No campaigns</div>}
            </div>
          ) : (
            <>
              <table className="hidden md:table" style={{ width: '100%', fontSize: 12 }}>
                <thead style={{ color: '#64748b', textAlign: 'left', position: 'sticky', top: 0, background: '#0f1119' }}>
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
                    <tr key={r.id} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                      <td style={{ padding: 10, fontFamily: 'monospace', fontSize: 11 }}>{r.email}</td>
                      <td style={{ padding: 10, color: '#94a3b8' }}>{r.name || '—'}</td>
                      <td style={{ padding: 10, fontWeight: 600 }} className={statusColor(r.status)}>{r.status}</td>
                      <td style={{ padding: 10, color: '#64748b', fontSize: 11 }}>{r.senderEmail || '—'}</td>
                      <td style={{ padding: 10, color: '#64748b', fontSize: 10 }}>
                        {r.sentAt ? new Date(r.sentAt).toLocaleString() : r.queuedAt ? new Date(r.queuedAt).toLocaleString() : '—'}
                      </td>
                      <td style={{ padding: 10, color: '#f87171', fontSize: 10, maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.error || ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="md:hidden">
                {filtered.map((r: any) => (
                  <div key={r.id} style={{ padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontFamily: 'monospace', fontSize: 12, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.email}</span>
                      <span className={statusColor(r.status)} style={{ fontSize: 11, fontWeight: 600, flexShrink: 0 }}>{r.status}</span>
                    </div>
                    {r.name && <div style={{ fontSize: 11, color: '#64748b' }}>{r.name}</div>}
                    {r.senderEmail && <div style={{ fontSize: 10, color: '#475569', marginTop: 2 }}>📤 {r.senderEmail}</div>}
                    {r.error && <div style={{ fontSize: 10, color: '#f87171', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.error}</div>}
                  </div>
                ))}
              </div>

              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>No items</div>}
            </>
          )}
        </div>
      </div>
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
