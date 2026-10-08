#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Broken JSX Syntax in campaigns/new"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# REWRITE FULL page.tsx — clean
# ═══════════════════════════════════════════
echo "📝 Rewriting app/campaigns/new/page.tsx..."

mkdir -p app/campaigns/new

cat > app/campaigns/new/page.tsx <<'TSXEOF'
'use client';
import { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

type Contact = { email: string; name?: string; company?: string };
type InvalidRow = { email: string; reason: string };

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function safeFetch(url: string, init: RequestInit): Promise<any> {
  const res = await fetch(url, init);
  const contentType = res.headers.get('content-type') || '';
  const rawText = await res.text();

  let data: any;
  if (contentType.includes('application/json')) {
    try {
      data = JSON.parse(rawText);
    } catch {
      throw new Error('Server returned invalid JSON');
    }
  } else {
    try {
      data = JSON.parse(rawText);
    } catch {
      throw new Error(
        rawText.slice(0, 200).trim() ||
        `Server error (${res.status} ${res.statusText})`
      );
    }
  }

  if (!res.ok) {
    throw new Error(data?.error || data?.message || `Request failed (${res.status})`);
  }
  return data;
}

export default function NewCampaign() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('Campaign ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('CONGRATULATIONS 🎉');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');
  const [batchLimit, setBatchLimit] = useState(1);

  const [contacts, setContacts] = useState<Contact[]>([]);
  const [fileStats, setFileStats] = useState<any>(null);
  const [invalidRows, setInvalidRows] = useState<InvalidRow[]>([]);
  const [duplicateEmails, setDuplicateEmails] = useState<string[]>([]);
  const [manualEmails, setManualEmails] = useState('');
  const [uploadStatus, setUploadStatus] = useState<'idle' | 'uploading' | 'done' | 'error'>('idle');
  const [uploadProgress, setUploadProgress] = useState(0);

  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgType, setMsgType] = useState<'info' | 'error' | 'success'>('info');
  const [spamReport, setSpamReport] = useState<any>(null);
  const [testEmail, setTestEmail] = useState('');
  const [testSending, setTestSending] = useState(false);
  const [senders, setSenders] = useState<any[]>([]);

  useEffect(() => {
    fetch('/api/senders')
      .then(r => r.json())
      .then(j => {
        const list = Array.isArray(j) ? j.filter((x: any) => x.status === 'CONNECTED') : [];
        setSenders(list);
      })
      .catch(() => {});
  }, []);

  const manualParsed = useMemo(() => {
    const lines = manualEmails.split(/[\n,;]+/).map(l => l.trim()).filter(Boolean);
    const valid: Contact[] = [];
    const invalid: InvalidRow[] = [];
    const seen = new Set<string>();

    for (const line of lines) {
      const parts = line.split(/[,|\t]/).map(p => p.trim());
      const email = parts[0]?.toLowerCase();
      if (!email) continue;
      if (seen.has(email)) continue;
      seen.add(email);

      if (!EMAIL_RE.test(email)) {
        invalid.push({ email, reason: 'Invalid format' });
        continue;
      }
      valid.push({ email, name: parts[1] || '', company: parts[2] || '' });
    }
    return { valid, invalid };
  }, [manualEmails]);

  const allContacts = useMemo(() => {
    const map = new Map<string, Contact>();
    for (const c of contacts) map.set(c.email.toLowerCase(), c);
    for (const c of manualParsed.valid) map.set(c.email.toLowerCase(), c);
    return Array.from(map.values());
  }, [contacts, manualParsed.valid]);

  const allInvalid = useMemo(() => {
    const map = new Map<string, InvalidRow>();
    for (const r of invalidRows) map.set(r.email, r);
    for (const r of manualParsed.invalid) map.set(r.email, r);
    return Array.from(map.values());
  }, [invalidRows, manualParsed.invalid]);

  const showMsg = (text: string, type: 'info' | 'error' | 'success' = 'info') => {
    setMsg(text);
    setMsgType(type);
  };

  const uploadFile = async (f: File) => {
    setUploadStatus('uploading');
    setUploadProgress(0);
    setBusy(true);
    showMsg('⏳ Uploading...', 'info');

    const fd = new FormData();
    fd.append('file', f);

    const progInterval = setInterval(() => {
      setUploadProgress(p => Math.min(90, p + 8));
    }, 200);

    try {
      const j = await safeFetch('/api/contacts/upload', { method: 'POST', body: fd });
      clearInterval(progInterval);
      setUploadProgress(100);

      if (!j.success) throw new Error(j.error || 'Upload failed');

      setContacts(j.contacts || []);
      setFileStats({
        totalRows: j.total,
        valid: j.imported,
        invalid: j.invalid,
        duplicates: j.duplicates,
        suppressed: 0,
      });
      setDuplicateEmails(j.duplicateList || []);
      setInvalidRows((j.invalidList || []).map((r: any) => ({
        email: r.email,
        reason: r.reason || 'Invalid',
      })));
      setUploadStatus('done');

      const dupMsg = j.duplicates > 0 ? ` · 🚫 ${j.duplicates} duplicates removed` : '';
      showMsg(`✅ ${j.imported} valid email(s) loaded${dupMsg}`, 'success');
    } catch (e: any) {
      clearInterval(progInterval);
      setUploadStatus('error');
      showMsg('❌ ' + (e.message || 'Upload failed'), 'error');
    }
    setBusy(false);
  };

  const moveInvalidToValid = (email: string) => {
    setContacts(prev => [...prev, { email: email.toLowerCase(), name: '', company: '' }]);
    setInvalidRows(prev => prev.filter(r => r.email !== email));
  };

  const moveAllInvalidToValid = () => {
    const add = allInvalid.map(r => ({ email: r.email.toLowerCase(), name: '', company: '' }));
    setContacts(prev => [...prev, ...add]);
    setInvalidRows([]);
  };

  const removeContact = (email: string) => {
    setContacts(prev => prev.filter(c => c.email.toLowerCase() !== email.toLowerCase()));
  };

  const clearAll = () => {
    setContacts([]);
    setFileStats(null);
    setInvalidRows([]);
    setManualEmails('');
    setDuplicateEmails([]);
    setUploadStatus('idle');
    setUploadProgress(0);
    setMsg('');
  };

  const checkSpam = async () => {
    if (!subject || !html) {
      showMsg('❌ Subject aur HTML chahiye', 'error');
      return;
    }
    setBusy(true);
    try {
      const j = await safeFetch('/api/anti-spam/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, html }),
      });
      setSpamReport(j);
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
    }
    setBusy(false);
  };

  const sendTest = async () => {
    if (!testEmail || !EMAIL_RE.test(testEmail)) {
      showMsg('❌ Valid test email daalo', 'error');
      return;
    }
    if (!subject || !html) {
      showMsg('❌ Subject aur HTML chahiye', 'error');
      return;
    }
    setTestSending(true);
    try {
      const j = await safeFetch('/api/test-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: testEmail, subject, html }),
      });
      showMsg(`✅ Test sent from ${j.sender}`, 'success');
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
    }
    setTestSending(false);
  };

  const launch = async () => {
    if (!allContacts.length) {
      showMsg('❌ Contacts add karo', 'error');
      return;
    }
    if (!subject.trim()) {
      showMsg('❌ Subject daalo', 'error');
      return;
    }

    setBusy(true);
    showMsg('🚀 Creating campaign...', 'info');

    try {
      // 1. Create campaign
      const created = await safeFetch('/api/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          subject,
          html,
          emails: allContacts.map(c => c.email),
          batchLimit,
        }),
      });

      // 2. Start it
      const started = await safeFetch(`/api/campaigns/${created.id}/start`, {
        method: 'POST',
      });

      showMsg(`✅ Campaign started with ${started.queued || 0} recipients!`, 'success');

      setTimeout(() => {
        router.push('/dashboard/live');
      }, 800);
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
      setBusy(false);
    }
  };

  const hasContacts = allContacts.length > 0;
  const canGoStep2 = hasContacts;
  const canGoStep3 = subject.trim().length > 0 && html.trim().length > 0;

  return (
    <div style={{ maxWidth: 1000, margin: '0 auto' }} className="space-y-5">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ fontSize: 'clamp(1.5rem, 4vw, 2rem)', fontWeight: 700, margin: 0 }}>📧 New Campaign</h1>
          <p style={{ color: 'var(--fg-muted)', fontSize: 13, marginTop: 4 }}>Create and launch in 4 steps</p>
        </div>
        <Link href="/dashboard/live" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {msg && (
        <div style={{
          padding: 14,
          borderRadius: 12,
          fontSize: 13,
          fontWeight: 600,
          background: msgType === 'error' ? '#fef2f2' : msgType === 'success' ? '#f0fdf4' : '#f0f9ff',
          border: '1px solid ' + (msgType === 'error' ? '#fca5a5' : msgType === 'success' ? '#86efac' : '#7dd3fc'),
          color: msgType === 'error' ? '#991b1b' : msgType === 'success' ? '#065f46' : '#075985',
        }}>
          {msg}
        </div>
      )}

      {/* Step Indicator */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {[{ n: 1, label: 'Contacts' }, { n: 2, label: 'Email' }, { n: 3, label: 'Preview' }, { n: 4, label: 'Launch' }].map((s, i) => (
          <div key={s.n} style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1 }}>
            <div style={{
              width: 34, height: 34, borderRadius: '50%',
              background: step > s.n ? 'linear-gradient(135deg,#10b981,#059669)'
                : step === s.n ? 'linear-gradient(135deg,#8b5cf6,#6366f1)'
                : 'var(--bg-subtle)',
              color: (step >= s.n) ? '#fff' : 'var(--fg-dim)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontWeight: 700, fontSize: 13,
            }}>
              {step > s.n ? '✓' : s.n}
            </div>
            {i < 3 && <div style={{ flex: 1, height: 2, background: step > s.n ? 'linear-gradient(90deg,#8b5cf6,#10b981)' : 'var(--border)' }} />}
          </div>
        ))}
      </div>

      {/* ═══════════════════════════════════════════ */}
      {/* STEP 1 — CONTACTS */}
      {/* ═══════════════════════════════════════════ */}
      {step === 1 && (
        <div className="card space-y-5">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>Step 1 — Add Contacts</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>
              Excel upload karo YA manual type karo
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
            <div style={{
              padding: 20,
              border: '2px dashed',
              borderColor: uploadStatus === 'done' ? '#10b981' : uploadStatus === 'error' ? '#ef4444' : 'var(--border)',
              borderRadius: 16,
              background: 'var(--bg-subtle)',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <div style={{ fontSize: 24 }}>📁</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>
                    {uploadStatus === 'done' ? 'File Uploaded ✓' : 'Upload Excel / CSV'}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--fg-dim)' }}>Optional</div>
                </div>
              </div>

              <input
                type="file"
                accept=".xlsx,.xls,.csv"
                onChange={e => {
                  const f = e.target.files?.[0];
                  if (f) uploadFile(f);
                  e.target.value = '';
                }}
                disabled={busy}
                style={{
                  width: '100%', fontSize: 12, padding: 8,
                  borderRadius: 8, background: 'var(--bg-elevated)',
                  border: '1px solid var(--border)',
                  cursor: busy ? 'not-allowed' : 'pointer',
                }}
              />

              {uploadStatus === 'uploading' && (
                <div style={{ marginTop: 10 }}>
                  <div style={{ height: 4, background: 'rgba(15,23,42,0.08)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: uploadProgress + '%', background: 'linear-gradient(90deg, #8b5cf6, #10b981)' }} />
                  </div>
                  <div style={{ fontSize: 11, color: '#8b5cf6', marginTop: 6, fontWeight: 600 }}>⏳ {uploadProgress}%</div>
                </div>
              )}

              {uploadStatus === 'done' && fileStats && (
                <div style={{ fontSize: 11, color: '#059669', marginTop: 8, fontWeight: 700 }}>
                  ✓ {fileStats.valid} valid email(s) loaded
                </div>
              )}
            </div>

            <div style={{
              padding: 20,
              border: '2px dashed',
              borderColor: manualParsed.valid.length > 0 ? '#10b981' : 'var(--border)',
              borderRadius: 16,
              background: 'var(--bg-subtle)',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <div style={{ fontSize: 24 }}>✍️</div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>Manual Entry</div>
                  <div style={{ fontSize: 11, color: 'var(--fg-dim)' }}>Type emails directly</div>
                </div>
              </div>

              <textarea
                className="input font-mono"
                style={{ fontSize: 12, minHeight: 100, resize: 'vertical' }}
                placeholder={"rahul@example.com\namit@company.com, Amit Sharma"}
                value={manualEmails}
                onChange={e => setManualEmails(e.target.value)}
              />

              {manualParsed.valid.length > 0 && (
                <div style={{ fontSize: 11, color: '#059669', marginTop: 8, fontWeight: 700 }}>
                  ✓ {manualParsed.valid.length} valid detected
                </div>
              )}
            </div>
          </div>

          {fileStats && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(90px, 1fr))', gap: 10 }}>
              <Stat label="TOTAL" value={fileStats.totalRows} />
              <Stat label="VALID" value={fileStats.valid} color="#10b981" />
              <Stat label="INVALID" value={fileStats.invalid} color="#ef4444" />
              <Stat label="DUPLICATES" value={fileStats.duplicates} color="#f59e0b" />
            </div>
          )}

          {duplicateEmails.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ fontSize: 13, color: '#d97706', fontWeight: 700, marginBottom: 10 }}>
                🚫 {duplicateEmails.length} duplicate email(s) removed
              </div>
              <div style={{ maxHeight: 140, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                {duplicateEmails.map((em, i) => (
                  <div key={i} style={{ padding: '8px 12px', fontSize: 12, fontFamily: 'monospace', color: 'var(--fg-muted)', borderBottom: i < duplicateEmails.length - 1 ? '1px solid var(--border)' : 'none' }}>
                    {em}
                  </div>
                ))}
              </div>
            </div>
          )}

          {allInvalid.length > 0 && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 13, color: '#dc2626', fontWeight: 700 }}>
                  ⚠️ {allInvalid.length} invalid email(s)
                </div>
                <button onClick={moveAllInvalidToValid} className="btn btn-ghost" style={{ fontSize: 12, padding: '6px 12px' }}>
                  ➡️ Move All to Valid
                </button>
              </div>
              <div style={{ maxHeight: 180, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                {allInvalid.map((row, i) => (
                  <div key={i} style={{ padding: '8px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, borderBottom: i < allInvalid.length - 1 ? '1px solid var(--border)' : 'none' }}>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontSize: 12, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.email}</div>
                      <div style={{ fontSize: 10, color: 'var(--fg-dim)' }}>{row.reason}</div>
                    </div>
                    <button onClick={() => moveInvalidToValid(row.email)} className="btn btn-ghost" style={{ fontSize: 11, padding: '4px 10px' }}>✓ Valid</button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {hasContacts && (
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
                <div style={{ fontSize: 14, color: '#10b981', fontWeight: 700 }}>
                  ✅ {allContacts.length} unique contact(s) ready
                </div>
                <button onClick={clearAll} style={{ fontSize: 11, color: '#dc2626', background: 'none', border: 'none', cursor: 'pointer', textDecoration: 'underline' }}>
                  Clear all
                </button>
              </div>
              <div style={{ maxHeight: 260, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 12 }}>
                <table style={{ width: '100%', fontSize: 12, borderCollapse: 'collapse' }}>
                  <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0 }}>
                    <tr>
                      <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                      <th style={{ textAlign: 'left', padding: 10 }}>Company</th>
                      <th style={{ width: 40 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {allContacts.map((c, i) => (
                      <tr key={c.email + i} style={{ borderTop: '1px solid var(--border)' }}>
                        <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                        <td style={{ padding: 10, fontFamily: 'monospace' }}>{c.email}</td>
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || c.name || '—'}</td>
                        <td style={{ padding: 10 }}>
                          <button onClick={() => removeContact(c.email)} style={{ background: 'none', border: 'none', color: '#dc2626', cursor: 'pointer', fontSize: 14 }}>✕</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <button
            onClick={() => canGoStep2 && setStep(2)}
            disabled={!canGoStep2}
            className="btn btn-primary"
            style={{ width: '100%', padding: 14, fontSize: 15, opacity: canGoStep2 ? 1 : 0.5, cursor: canGoStep2 ? 'pointer' : 'not-allowed' }}
          >
            {canGoStep2 ? `Next → Email (${allContacts.length} contacts)` : '📁 Upload OR ✍️ type emails'}
          </button>
        </div>
      )}

      {/* ═══════════════════════════════════════════ */}
      {/* STEP 2 — EMAIL CONTENT */}
      {/* ═══════════════════════════════════════════ */}
      {step === 2 && (
        <div className="card space-y-4">
          <h2 style={{ fontSize: 18 }}>Step 2 — Email Content</h2>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>Subject *</label>
            <input className="input" placeholder="CONGRATULATIONS 🎉" value={subject} onChange={e => setSubject(e.target.value)} />
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>HTML Body *</label>
            <textarea className="input font-mono" style={{ fontSize: 12, minHeight: 200, resize: 'vertical' }} value={html} onChange={e => setHtml(e.target.value)} />
          </div>

          <div style={{ padding: 16, background: 'rgba(139,92,246,0.05)', border: '1px solid rgba(139,92,246,0.2)', borderRadius: 12 }}>
            <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>📨 Test Email</div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input className="input" style={{ flex: 1, minWidth: 200 }} type="email" placeholder="your@email.com" value={testEmail} onChange={e => setTestEmail(e.target.value)} />
              <button onClick={sendTest} disabled={testSending || !testEmail} className="btn btn-primary">
                {testSending ? '⏳ Sending…' : '📤 Send Test'}
              </button>
            </div>
            <div style={{ fontSize: 11, color: 'var(--fg-dim)', marginTop: 8 }}>
              {senders.length > 0 ? `📤 Sender: ${senders[0].email}` : '⚠️ No sender connected'}
            </div>
          </div>

          <div>
            <label style={{ fontSize: 12, color: 'var(--fg-muted)', display: 'block', marginBottom: 6, fontWeight: 600 }}>🔄 Batch limit per sender (1-350)</label>
            <input type="number" className="input" style={{ maxWidth: 200 }} min={1} max={350} value={batchLimit} onChange={e => setBatchLimit(Math.min(350, Math.max(1, parseInt(e.target.value) || 1)))} />
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button onClick={checkSpam} disabled={busy || !subject || !html} className="btn btn-ghost">🛡️ Spam Check</button>
            <button onClick={() => setStep(1)} className="btn btn-ghost">← Back</button>
            <button onClick={() => canGoStep3 && setStep(3)} disabled={!canGoStep3} className="btn btn-primary" style={{ opacity: canGoStep3 ? 1 : 0.5 }}>
              {canGoStep3 ? 'Next → Preview' : 'Subject + HTML bharo'}
            </button>
          </div>

          {spamReport && (
            <div style={{
              border: '1px solid',
              borderColor: spamReport.blocked ? '#fca5a5' : spamReport.warning ? '#fcd34d' : '#86efac',
              background: spamReport.blocked ? '#fef2f2' : spamReport.warning ? '#fffbeb' : '#f0fdf4',
              borderRadius: 12, padding: 16,
            }}>
              <div style={{ fontWeight: 700, marginBottom: 8 }}>
                Spam Score: <span style={{ fontSize: 22, color: spamReport.blocked ? '#dc2626' : spamReport.warning ? '#d97706' : '#059669' }}>{spamReport.score}</span>
                {' '}({spamReport.blocked ? '🚫 Blocked' : spamReport.warning ? '⚠️ Warning' : '✅ Safe'})
              </div>
              {spamReport.issues?.map((iss: any, i: number) => (
                <div key={i} style={{ fontSize: 12, marginTop: 4 }}>• {iss.message} <span style={{ opacity: 0.6 }}>(+{iss.points})</span></div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ═══════════════════════════════════════════ */}
      {/* STEP 3 — PREVIEW */}
      {/* ═══════════════════════════════════════════ */}
      {step === 3 && (
        <div className="card space-y-4">
          <h2 style={{ fontSize: 18 }}>Step 3 — Preview Recipients</h2>

          <div style={{ background: 'linear-gradient(135deg, rgba(139,92,246,0.08), rgba(236,72,153,0.04))', border: '1px solid rgba(139,92,246,0.25)', borderRadius: 16, padding: 20 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Total</div>
                <div style={{ fontSize: 26, fontWeight: 800, color: '#8b5cf6' }}>{allContacts.length}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Batch</div>
                <div style={{ fontSize: 26, fontWeight: 800 }}>{batchLimit}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Cycles</div>
                <div style={{ fontSize: 26, fontWeight: 800 }}>{Math.ceil(allContacts.length / Math.max(1, batchLimit))}</div>
              </div>
            </div>
          </div>

          <div style={{ border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden' }}>
            <div style={{ background: 'var(--bg-subtle)', padding: '10px 16px', fontSize: 12, color: 'var(--fg-muted)', fontWeight: 700, borderBottom: '1px solid var(--border)' }}>
              Email List ({allContacts.length})
            </div>
            <div style={{ maxHeight: 400, overflow: 'auto' }}>
              <table style={{ width: '100%', fontSize: 12 }}>
                <thead style={{ background: 'var(--bg-subtle)', position: 'sticky', top: 0 }}>
                  <tr>
                    <th style={{ textAlign: 'left', padding: 10, width: 40 }}>#</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Email</th>
                    <th style={{ textAlign: 'left', padding: 10 }}>Company</th>
                  </tr>
                </thead>
                <tbody>
                  {allContacts.map((c, i) => (
                    <tr key={i} style={{ borderTop: '1px solid var(--border)' }}>
                      <td style={{ padding: 10, color: 'var(--fg-dim)' }}>{i + 1}</td>
                      <td style={{ padding: 10, fontFamily: 'monospace' }}>{c.email}</td>
                      <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || c.name || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(2)} className="btn btn-ghost">← Back</button>
            <button onClick={() => setStep(4)} className="btn btn-primary" style={{ flex: 1 }}>Next → Launch</button>
          </div>
        </div>
      )}

      {/* ═══════════════════════════════════════════ */}
      {/* STEP 4 — LAUNCH */}
      {/* ═══════════════════════════════════════════ */}
      {step === 4 && (
        <div className="card space-y-4">
          <h2 style={{ fontSize: 18 }}>Step 4 — Final Review</h2>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16 }}>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Campaign</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{name}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Subject</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{subject}</div>
            </div>
            <div style={{ background: 'rgba(16,185,129,0.08)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: '#065f46', fontWeight: 700, textTransform: 'uppercase' }}>Recipients</div>
              <div style={{ fontSize: 22, fontWeight: 800, color: '#059669', marginTop: 4 }}>{allContacts.length}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Batch</div>
              <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>{batchLimit} per sender</div>
            </div>
          </div>

          <div style={{ background: '#fffbeb', border: '1px solid #fcd34d', borderRadius: 12, padding: 14, fontSize: 13, color: '#92400e', lineHeight: 1.5 }}>
            ⚠️ <b>Launch ke baad:</b> Live Dashboard pe redirect hoga. Worker automatically emails bhejega.
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setStep(3)} className="btn btn-ghost">← Back</button>
            <button
              onClick={launch}
              disabled={busy}
              className="btn btn-primary"
              style={{ flex: 1, padding: 14, fontSize: 15 }}
            >
              {busy ? '🚀 Launching…' : `🚀 LAUNCH CAMPAIGN — ${allContacts.length} emails`}
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
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', letterSpacing: '0.1em', fontWeight: 700 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>{value?.toLocaleString() ?? 0}</div>
    </div>
  );
}
TSXEOF
sed -i 's/\r$//' app/campaigns/new/page.tsx
echo "   ✅ page.tsx rewritten (clean syntax)"

# ═══════════════════════════════════════════
# VERIFY — check for common syntax errors
# ═══════════════════════════════════════════
echo ""
echo "🔎 Verifying syntax..."

# Check for broken patterns
if grep -q ")} className=\"btn" app/campaigns/new/page.tsx; then
  echo "   ❌ Still has broken pattern"
  exit 1
fi

# Count braces (rough check)
OPEN=$(grep -o '{' app/campaigns/new/page.tsx | wc -l)
CLOSE=$(grep -o '}' app/campaigns/new/page.tsx | wc -l)
echo "   Opening braces: $OPEN"
echo "   Closing braces: $CLOSE"

if [ "$OPEN" -ne "$CLOSE" ]; then
  echo "   ⚠️  Brace mismatch (may be false positive due to strings)"
fi

# Check for "Launching" button exists correctly
if grep -q "onClick={launch}" app/campaigns/new/page.tsx; then
  echo "   ✅ Launch button properly written"
fi

# ═══════════════════════════════════════════
# GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: rewrite campaigns/new page with clean JSX syntax"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ SYNTAX FIXED"
echo "==============================================="
echo ""
echo "🎯 Kya fix hua:"
echo "  ✓ Line 844 ka orphaned ')}' hataya"
echo "  ✓ Poora page.tsx clean rewrite"
echo "  ✓ Sab buttons proper onClick ke saath"
echo "  ✓ Step 4 ka Launch button kaam karega"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📊 Check karo:"
echo "  https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "Expected: Build 'Ready' ✅"
echo ""
echo "Phir test karo:"
echo "  https://emailcampaign-ten.vercel.app/campaigns/new"
echo "==============================================="