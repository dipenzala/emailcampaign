'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from '@/components/Toast';

type Contact = { email: string; name?: string; company?: string };
type InvalidRow = { email: string; reason: string };

export default function NewCampaign() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('Campaign ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [batchLimit, setBatchLimit] = useState(1);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [spamReport, setSpamReport] = useState<any>(null);
  const [manualEmails, setManualEmails] = useState('');
  const [invalidRows, setInvalidRows] = useState<InvalidRow[]>([]);
  const [testEmail, setTestEmail] = useState('');
  const [testSending, setTestSending] = useState(false);
  const [senders, setSenders] = useState<any[]>([]);

  useEffect(() => {
    const s = localStorage.getItem('ec_manual');
    if (s) setManualEmails(s);
    fetch('/api/senders').then(r => r.json()).then(j => {
      const list = Array.isArray(j) ? j.filter((x: any) => x.status === 'CONNECTED') : [];
      setSenders(list);
    }).catch(() => {});
  }, []);

  useEffect(() => { localStorage.setItem('ec_manual', manualEmails); }, [manualEmails]);

  const uploadFile = async (f: File) => {
    setBusy(true); setMsg('');
    const fd = new FormData(); fd.append('file', f);
    try {
      const r = await fetch('/api/contacts/upload', { method: 'POST', body: fd });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Upload failed');
      setContacts(j.contacts || []);
      setStats(j);
      setInvalidRows([]);
      setMsg(`✅ ${j.valid} valid emails loaded from file`);
      toast(`Loaded ${j.valid} emails`, 'success');
    } catch (e: any) { setMsg('❌ ' + e.message); }
    setBusy(false);
  };

  const parseManual = () => {
    const lines = manualEmails.split(/[\n,;]+/).map(l => l.trim()).filter(Boolean);
    const valid: Contact[] = [];
    const invalid: InvalidRow[] = [];
    const seen = new Set(contacts.map(c => c.email.toLowerCase()));

    for (const line of lines) {
      const parts = line.split(/[,|\t]/).map(p => p.trim());
      const email = parts[0]?.toLowerCase();
      if (!email) continue;

      // If same email already exists, skip
      if (seen.has(email)) continue;
      seen.add(email);

      // Validate
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
        invalid.push({ email, reason: 'Invalid format' });
        continue;
      }
      valid.push({ email, name: parts[1] || '', company: parts[2] || '' });
    }

    if (valid.length > 0) setContacts([...contacts, ...valid]);
    if (invalid.length > 0) setInvalidRows(prev => [...prev, ...invalid]);

    setMsg(
      `✅ Added ${valid.length} valid` +
      (invalid.length ? ` · ⚠️ ${invalid.length} invalid (see below)` : '')
    );
    toast(`+${valid.length} emails`, 'success');
  };

  const moveInvalidToValid = (email: string) => {
    // Best guess: add with empty name/company
    setContacts([...contacts, { email: email.toLowerCase(), name: '', company: '' }]);
    setInvalidRows(prev => prev.filter(r => r.email !== email));
    toast('Moved to valid list', 'success');
  };

  const moveAllInvalidToValid = () => {
    const add = invalidRows.map(r => ({ email: r.email.toLowerCase(), name: '', company: '' }));
    setContacts([...contacts, ...add]);
    setInvalidRows([]);
    toast(`Moved ${add.length} emails`, 'success');
  };

  const removeContact = (i: number) => {
    setContacts(contacts.filter((_, j) => j !== i));
  };

  const checkSpam = async () => {
    setBusy(true);
    try {
      const r = await fetch('/api/anti-spam/check', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, html }),
      });
      setSpamReport(await r.json());
    } catch {}
    setBusy(false);
  };

  const sendTest = async () => {
    if (!testEmail || !subject || !html) {
      toast('Test email, subject aur HTML chahiye', 'error');
      return;
    }
    setTestSending(true);
    try {
      const r = await fetch('/api/test-email', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: testEmail, subject, html }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Failed');
      toast(`✅ Test email sent from ${j.sender}`, 'success');
    } catch (e: any) { toast('❌ ' + e.message, 'error'); }
    setTestSending(false);
  };

  const launch = async () => {
    if (!contacts.length) { setMsg('❌ Contacts add karo'); return; }
    if (!subject.trim()) { setMsg('❌ Subject daalo'); return; }
    setBusy(true); setMsg('');
    try {
      const r = await fetch('/api/campaigns', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          emails: contacts.map(c => c.email),
          batchLimit,
        }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error?.message || JSON.stringify(j.error) || 'Create failed');

      const sr = await fetch(`/api/campaigns/${j.id}/start`, { method: 'POST' });
      const sj = await sr.json();
      if (!sr.ok) throw new Error(sj.error || 'Start failed');

      toast('🚀 Campaign started', 'success');
      router.push('/dashboard/live');
    } catch (e: any) {
      setMsg('❌ ' + e.message);
      setBusy(false);
    }
  };

  const canGoNext1 = contacts.length > 0;

  return (
    <div className="space-y-5 max-w-4xl mx-auto">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">📧 New Campaign</h1>
        <Link href="/dashboard/live" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {msg && <div className="card text-sm" style={{ padding: 16 }}>{msg}</div>}

      {/* Step indicator */}
      <div className="flex items-center gap-2">
        {[1, 2, 3, 4].map(n => (
          <div key={n} className="flex items-center gap-2 flex-1">
            <div style={{
              width: 32, height: 32, borderRadius: '50%',
              background: step >= n ? 'linear-gradient(135deg,#8b5cf6,#6366f1)' : 'var(--bg-subtle)',
              color: step >= n ? '#fff' : 'var(--fg-dim)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontWeight: 700, fontSize: 13,
            }}>{n}</div>
            <div style={{ fontSize: 12, color: step >= n ? 'var(--fg)' : 'var(--fg-dim)' }}>
              {n === 1 ? 'Contacts' : n === 2 ? 'Email' : n === 3 ? 'Preview' : 'Launch'}
            </div>
            {n < 4 && <div style={{ flex: 1, height: 2, background: step > n ? '#8b5cf6' : 'var(--border)' }} />}
          </div>
        ))}
      </div>

      {/* STEP 1: Contacts */}
      {step === 1 && (
        <div className="card space-y-5">
          <h2>Step 1 — Contacts</h2>

          {/* File Upload (OPTIONAL) */}
          <div style={{ padding: 16, background: 'var(--bg-subtle)', borderRadius: 12 }}>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 8 }}>
              📁 Optional: Upload Excel / CSV
            </label>
            <input
              type="file"
              accept=".xlsx,.xls,.csv"
              onChange={e => e.target.files?.[0] && uploadFile(e.target.files[0])}
              className="input"
              disabled={busy}
            />
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 6 }}>
              Ya neeche manually emails add karo (file ki zaroorat nahi)
            </div>
          </div>

          {/* Manual Entry */}
          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 8 }}>
              ✍️ Manual Emails (one per line)
            </label>
            <textarea
              className="input font-mono"
              style={{ fontSize: 13 }}
              rows={6}
              placeholder={"rahul@example.com\namit@company.com, Amit Sharma\npriya@startup.io, Priya Patel, Acme Corp"}
              value={manualEmails}
              onChange={e => setManualEmails(e.target.value)}
            />
            <button
              onClick={parseManual}
              disabled={!manualEmails.trim() || busy}
              className="btn btn-ghost"
              style={{ marginTop: 8 }}
            >
              ➕ Add Emails
            </button>
          </div>

          {/* Stats from file */}
          {stats && (
            <div className="grid grid-cols-2 md:grid-cols-5 gap-3" style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
              <Stat label="TOTAL" value={stats.totalRows} />
              <Stat label="VALID" value={stats.valid} color="#10b981" />
              <Stat label="INVALID" value={stats.invalid} color="#ef4444" />
              <Stat label="DUPES" value={stats.duplicates} color="#f59e0b" />
              <Stat label="SUPPRESSED" value={stats.suppressed} color="#6b7280" />
            </div>
          )}

          {/* Invalid emails — move option */}
          {invalidRows.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 13, color: '#dc2626', fontWeight: 600 }}>
                  ⚠️ {invalidRows.length} invalid emails
                </div>
                <button onClick={moveAllInvalidToValid} className="btn btn-ghost text-xs">
                  ➡️ Move All to Valid
                </button>
              </div>
              <div style={{ maxHeight: 200, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                {invalidRows.map((row, i) => (
                  <div key={i} style={{
                    padding: '8px 12px',
                    borderBottom: i < invalidRows.length - 1 ? '1px solid var(--border)' : 'none',
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8,
                  }}>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontSize: 12, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.email}</div>
                      <div style={{ fontSize: 10, color: 'var(--fg-dim)' }}>{row.reason}</div>
                    </div>
                    <button
                      onClick={() => moveInvalidToValid(row.email)}
                      className="btn btn-ghost"
                      style={{ fontSize: 11, padding: '5px 10px' }}
                    >
                      ✓ Valid
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Contacts preview */}
          {contacts.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
              <div style={{ fontSize: 13, color: '#10b981', fontWeight: 600, marginBottom: 12 }}>
                ✅ {contacts.length} contacts ready
                <button
                  onClick={() => { setContacts([]); setStats(null); setInvalidRows([]); }}
                  style={{ fontSize: 11, color: '#dc2626', marginLeft: 12, background: 'none', border: 'none', cursor: 'pointer', textDecoration: 'underline' }}
                >
                  Clear all
                </button>
              </div>
              <div style={{ maxHeight: 240, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                <table style={{ width: '100%', fontSize: 12 }}>
                  <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0 }}>
                    <tr>
                      <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Name</th>
                      <th style={{ width: 40 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {contacts.map((c, i) => (
                      <tr key={i} style={{ borderTop: '1px solid var(--border)' }}>
                        <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                        <td style={{ padding: 10 }}>{c.email}</td>
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.name || '—'}</td>
                        <td style={{ padding: 10 }}>
                          <button onClick={() => removeContact(i)} style={{ background: 'none', border: 'none', color: '#dc2626', cursor: 'pointer' }}>✕</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <button
            onClick={() => setStep(2)}
            disabled={!canGoNext1}
            className="btn btn-primary"
          >
            {canGoNext1 ? `Next → Email (${contacts.length} contacts)` : 'Add contacts to continue'}
          </button>
        </div>
      )}

      {/* STEP 2: Email Content */}
      {step === 2 && (
        <div className="card space-y-4">
          <h2>Step 2 — Email Content</h2>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>Subject</label>
            <input className="input" placeholder="Hello {{name}}, quick update" value={subject} onChange={e => setSubject(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>HTML Body</label>
            <textarea className="input font-mono" style={{ fontSize: 12 }} rows={12} value={html} onChange={e => setHtml(e.target.value)} />
          </div>

          {/* Test Email */}
          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>
              📨 Test Email Send Karo (pehle check karo)
            </label>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input
                className="input"
                style={{ flex: 1, minWidth: 200 }}
                type="email"
                placeholder="your@email.com"
                value={testEmail}
                onChange={e => setTestEmail(e.target.value)}
              />
              <button onClick={sendTest} disabled={testSending || !testEmail} className="btn btn-ghost">
                {testSending ? '⏳ Sending…' : '📤 Send Test'}
              </button>
            </div>
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 6 }}>
              {senders.length > 0 ? `Sender: ${senders[0].email}` : 'No sender connected'}
            </div>
          </div>

          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 20 }}>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 4 }}>
              🔄 Batch limit (per sender)
            </label>
            <input
              type="number"
              className="input"
              style={{ maxWidth: 200 }}
              min={1}
              max={350}
              value={batchLimit}
              onChange={e => setBatchLimit(parseInt(e.target.value) || 1)}
            />
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 4 }}>
              1 = Strict one-by-one · 350 = max per sender
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button onClick={checkSpam} disabled={busy} className="btn btn-ghost">🛡️ Spam Check</button>
            <button onClick={() => setStep(1)} className="btn btn-ghost">← Back</button>
            <button onClick={() => setStep(3)} className="btn btn-primary" disabled={!subject || !html}>Next → Preview</button>
          </div>

          {spamReport && (
            <div style={{
              border: '1px solid',
              borderColor: spamReport.blocked ? '#fca5a5' : spamReport.warning ? '#fcd34d' : '#86efac',
              background: spamReport.blocked ? '#fef2f2' : spamReport.warning ? '#fffbeb' : '#f0fdf4',
              borderRadius: 12,
              padding: 16,
            }}>
              <div style={{ fontWeight: 600, marginBottom: 8 }}>
                Spam Score: <span style={{ fontSize: 20, color: spamReport.blocked ? '#dc2626' : spamReport.warning ? '#d97706' : '#059669' }}>{spamReport.score}</span>
                {' '}({spamReport.blocked ? '🚫 Blocked' : spamReport.warning ? '⚠️ Warning' : '✅ Safe'})
              </div>
              {spamReport.issues?.map((iss: any, i: number) => (
                <div key={i} style={{ fontSize: 12, marginTop: 4 }}>• {iss.message} <span style={{ opacity: 0.6 }}>(+{iss.points})</span></div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* STEP 3: Preview */}
      {step === 3 && (
        <div className="card space-y-4">
          <h2>👁️ Step 3 — Preview Recipients</h2>
          <p style={{ fontSize: 13, color: 'var(--fg-muted)' }}>Ye list check karo — sirf inhi emails ko message jayega.</p>

          <div style={{ background: 'rgba(139,92,246,0.06)', border: '1px solid rgba(139,92,246,0.2)', borderRadius: 12, padding: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>TOTAL</div>
                <div style={{ fontSize: 22, fontWeight: 700, color: '#8b5cf6' }}>{contacts.length}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>BATCH</div>
                <div style={{ fontSize: 22, fontWeight: 700 }}>{batchLimit}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)' }}>CYCLES</div>
                <div style={{ fontSize: 22, fontWeight: 700 }}>{Math.ceil(contacts.length / Math.max(1, batchLimit))}</div>
              </div>
            </div>
          </div>

          <div style={{ border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden' }}>
            <div style={{ background: 'var(--bg-subtle)', padding: '10px 16px', fontSize: 12, color: 'var(--fg-muted)', borderBottom: '1px solid var(--border)' }}>
              Email List ({contacts.length})
            </div>
            <div style={{ maxHeight: 400, overflow: 'auto' }}>
              <table style={{ width: '100%', fontSize: 12 }}>
                <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0 }}>
                  <tr>
                    <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Name</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Company</th>
                  </tr>
                </thead>
                <tbody>
                  {contacts.map((c, i) => (
                    <tr key={i} style={{ borderTop: '1px solid var(--border)' }}>
                      <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                      <td style={{ padding: 10, fontFamily: 'monospace' }}>{c.email}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.name || '—'}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(2)} className="btn btn-ghost">← Back</button>
            <button onClick={() => setStep(4)} className="btn btn-primary">Next → Launch</button>
          </div>
        </div>
      )}

      {/* STEP 4: Review */}
      {step === 4 && (
        <div className="card space-y-4">
          <h2>🚀 Step 4 — Final Review</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16, fontSize: 14 }}>
            <div><div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Campaign</div><div style={{ fontWeight: 600 }}>{name}</div></div>
            <div><div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Subject</div><div style={{ fontWeight: 600 }}>{subject}</div></div>
            <div><div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Recipients</div><div style={{ fontWeight: 600, color: '#10b981' }}>{contacts.length}</div></div>
            <div><div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>Batch Limit</div><div style={{ fontWeight: 600 }}>{batchLimit}</div></div>
          </div>
          <div style={{ background: '#fffbeb', border: '1px solid #fcd34d', borderRadius: 12, padding: 12, fontSize: 12, color: '#92400e' }}>
            ⚠️ Launch ke baad Live Dashboard pe redirect hoga. Emails worker se automatically jayengi.
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(3)} className="btn btn-ghost">← Back</button>
            <button onClick={launch} disabled={busy} className="btn btn-primary">
              {busy ? '🚀 Launching…' : `🚀 LAUNCH — ${contacts.length} emails`}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 12, padding: 12 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', letterSpacing: '0.1em' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color, marginTop: 4 }}>{value?.toLocaleString() ?? 0}</div>
    </div>
  );
}
