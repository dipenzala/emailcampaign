'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function InboxPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [selected, setSelected] = useState('');
  const [messages, setMessages] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [preview, setPreview] = useState<any>(null);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetch('/api/senders').then(r => r.json()).then(j => {
      const list = Array.isArray(j) ? j.filter((s: any) => s.status === 'CONNECTED') : [];
      setSenders(list);
      if (list[0]) setSelected(list[0].email);
    });
  }, []);

  const load = async (sender?: string) => {
    setLoading(true); setError('');
    try {
      const url = '/api/inbox' + (sender ? `?sender=${encodeURIComponent(sender)}` : '');
      const r = await fetch(url);
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || 'Failed');
      setMessages(j.messages || []);
    } catch (e: any) { setError(e.message); setMessages([]); }
    setLoading(false);
  };

  useEffect(() => { if (selected) load(selected); }, [selected]);

  const openMessage = async (id: string) => {
    try {
      const r = await fetch(`/api/inbox/${id}`);
      const j = await r.json();
      if (j.ok) setPreview(j);
      else setError(j.error);
    } catch (e: any) { setError(e.message); }
  };

  const filtered = search
    ? messages.filter(m =>
        (m.from || '').toLowerCase().includes(search.toLowerCase()) ||
        (m.fromName || '').toLowerCase().includes(search.toLowerCase()) ||
        (m.subject || '').toLowerCase().includes(search.toLowerCase()) ||
        (m.snippet || '').toLowerCase().includes(search.toLowerCase()))
    : messages;

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>📥 Client Replies</h1>
        <p className="subtitle">Gmail inbox se live replies — jo bhi reply karega yahan dikhega</p>
      </div>

      {senders.length === 0 ? (
        <div className="card text-center" style={{ padding: 48 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
          <p style={{ color: 'var(--fg-muted)', marginBottom: 16 }}>Koi sender connected nahi</p>
          <Link href="/senders" className="btn btn-primary">Connect Sender</Link>
        </div>
      ) : (
        <>
          <div className="card" style={{ padding: 16 }}>
            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 200 }}>
                <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>Sender</label>
                <select className="input" value={selected} onChange={e => setSelected(e.target.value)}>
                  {senders.map(s => <option key={s.id} value={s.email}>{s.email}</option>)}
                </select>
              </div>
              <div style={{ flex: 1, minWidth: 200 }}>
                <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>Search</label>
                <input className="input" placeholder="🔍 Search..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                <button onClick={() => load(selected)} disabled={loading} className="btn btn-primary">
                  {loading ? '⏳' : '🔄 Refresh'}
                </button>
              </div>
            </div>
          </div>

          {error && (
            <div className="card" style={{ background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
              <div style={{ fontWeight: 600, marginBottom: 4 }}>❌ Error</div>
              <div style={{ fontSize: 13 }}>{error}</div>
              {/scope|permission/i.test(error) && (
                <div style={{ fontSize: 12, marginTop: 8 }}>
                  → <Link href="/senders" style={{ textDecoration: 'underline' }}>Senders page</Link> pe reconnect karo (naya scope allow karo)
                </div>
              )}
            </div>
          )}

          {loading ? (
            <div className="card text-center" style={{ padding: 48, color: 'var(--fg-muted)' }}>Loading messages...</div>
          ) : filtered.length === 0 ? (
            <div className="card text-center" style={{ padding: 48 }}>
              <div style={{ fontSize: 40, marginBottom: 8 }}>📭</div>
              <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>Koi reply nahi mila</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {filtered.map(m => (
                <button
                  key={m.id}
                  onClick={() => openMessage(m.id)}
                  className="card"
                  style={{
                    textAlign: 'left',
                    cursor: 'pointer',
                    padding: 16,
                    borderLeftWidth: m.isUnread ? 4 : 1,
                    borderLeftColor: m.isUnread ? '#8b5cf6' : 'var(--border)',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, marginBottom: 6 }}>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: 600, fontSize: 14, color: m.isUnread ? 'var(--fg)' : 'var(--fg-muted)' }}>
                          {m.fromName || m.from}
                        </span>
                        {m.isUnread && (
                          <span style={{ fontSize: 9, fontWeight: 700, padding: '2px 8px', borderRadius: 6, background: 'rgba(139,92,246,0.15)', color: '#8b5cf6' }}>NEW</span>
                        )}
                      </div>
                      <div style={{ fontSize: 11, color: 'var(--fg-dim)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.from}</div>
                    </div>
                    <div style={{ fontSize: 10, color: 'var(--fg-dim)', flexShrink: 0 }}>
                      {m.date ? new Date(m.date).toLocaleDateString() : ''}
                    </div>
                  </div>
                  <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 4 }}>{m.subject || '(no subject)'}</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-muted)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{m.snippet}</div>
                </button>
              ))}
            </div>
          )}
        </>
      )}

      {preview && (
        <div className="modal-backdrop" onClick={() => setPreview(null)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, marginBottom: 16 }}>
              <div style={{ minWidth: 0, flex: 1 }}>
                <h2 style={{ fontSize: 18, marginBottom: 4 }}>{preview.subject || '(no subject)'}</h2>
                <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
                  <div><b>From:</b> {preview.from}</div>
                  <div><b>To:</b> {preview.to}</div>
                  <div><b>Date:</b> {preview.date ? new Date(preview.date).toLocaleString() : ''}</div>
                </div>
              </div>
              <button onClick={() => setPreview(null)} className="btn btn-ghost" style={{ padding: '6px 12px' }}>✕</button>
            </div>
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div
                style={{ fontSize: 14, lineHeight: 1.6 }}
                dangerouslySetInnerHTML={{ __html: preview.body || preview.snippet || '(empty)' }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
