'use client';
import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from '@/components/Toast';

type Row = { email: string; company: string };

export default function ScheduledCampaignNew() {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);

  const [step, setStep] = useState(1);
  const [name, setName] = useState('Scheduled ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('CONGRATULATIONS 🎉');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');

  const [startHour, setStartHour] = useState(10);
  const [startMinute, setStartMinute] = useState(0);
  const [durationMinutes, setDurationMinutes] = useState(120); // 2 hours

  const [rows, setRows] = useState<Row[]>([]);
  const [fileStats, setFileStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [campaignId, setCampaignId] = useState<string | null>(null);

  const CHUNK_SIZE = 5000;

  // ═══════════════════════════════════════════
  // Excel parsing (client-side)
  // ═══════════════════════════════════════════
  const handleFile = async (f: File) => {
    setBusy(true);
    setUploadProgress(0);
    try {
      const XLSX = await import('xlsx');
      const buf = await f.arrayBuffer();
      const wb = XLSX.read(buf, { type: 'array' });
      const sheet = wb.Sheets[wb.SheetNames[0]];
      const raw: any[] = XLSX.utils.sheet_to_json(sheet, { defval: '', raw: false });

      if (!raw.length) throw new Error('File has no rows');

      // Find email + company columns
      const headers = Object.keys(raw[0] || {});
      const norm = (s: string) => String(s).toLowerCase().replace(/[_\-\s]/g, '');
      const emailKey = headers.find(h => ['email', 'emailaddress', 'mail'].includes(norm(h))) ||
                       headers.find(h => raw.slice(0, 5).some(r => String(r[h] || '').includes('@')));
      const companyKey = headers.find(h => /company|organi|business|firm/.test(norm(h))) ||
                         headers.filter(h => h !== emailKey)[0];

      if (!emailKey) throw new Error('No email column found');

      const parsed: Row[] = [];
      const seen = new Set<string>();
      let invalid = 0, duplicates = 0;

      for (const r of raw) {
        const email = String(r[emailKey] || '').trim().toLowerCase();
        if (!email) { invalid++; continue; }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { invalid++; continue; }
        if (seen.has(email)) { duplicates++; continue; }
        seen.add(email);
        parsed.push({
          email,
          company: companyKey ? String(r[companyKey] || '').trim() : '',
        });
      }

      setRows(parsed);
      setFileStats({
        total: raw.length,
        valid: parsed.length,
        invalid,
        duplicates,
      });
      toast(`✅ ${parsed.length} valid emails loaded`, 'success');
    } catch (e: any) {
      toast('❌ ' + e.message, 'error');
    }
    setBusy(false);
  };

  // ═══════════════════════════════════════════
  // Create campaign + chunk upload
  // ═══════════════════════════════════════════
  const launch = async () => {
    if (!rows.length) { toast('Add emails first', 'error'); return; }
    if (!subject.trim() || !html.trim()) { toast('Subject + HTML required', 'error'); return; }

    setBusy(true);
    setUploadProgress(0);

    try {
      // Create campaign
      const r = await fetch('/api/campaigns/scheduled', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          scheduleStartHour: startHour,
          scheduleStartMinute: startMinute,
          scheduleDurationMinutes: durationMinutes,
        }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      const newCampaignId = j.id;
      setCampaignId(newCampaignId);

      // Upload in chunks
      const totalChunks = Math.ceil(rows.length / CHUNK_SIZE);
      for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
        const slice = rows.slice(i, i + CHUNK_SIZE);
        const isFinal = (i + CHUNK_SIZE) >= rows.length;

        const cr = await fetch('/api/campaigns/scheduled/upload-chunk', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            campaignId: newCampaignId,
            rows: slice,
            finalize: isFinal,
          }),
        });
        const cj = await cr.json();
        if (!cj.ok) throw new Error(cj.error);

        const chunkIdx = Math.floor(i / CHUNK_SIZE) + 1;
        setUploadProgress(Math.round((chunkIdx / totalChunks) * 100));
      }

      // Set campaign to RUNNING
      await fetch(`/api/campaigns/${newCampaignId}/start`, { method: 'POST' });

      toast('🎉 Scheduled campaign created!', 'success');
      setTimeout(() => router.push('/campaigns/scheduled'), 1500);
    } catch (e: any) {
      toast('❌ ' + e.message, 'error');
      setBusy(false);
    }
  };

  // Compute end time display
  const endTime = (() => {
    const total = startHour * 60 + startMinute + durationMinutes;
    return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
  })();

  return (
    <div className="space-y-5 max-w-4xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">⏰ Scheduled Campaign</h1>
          <p className="text-sm text-slate-400 mt-1">Daily time-window bulk sender</p>
        </div>
        <Link href="/campaigns/scheduled" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {/* STEP 1 — Schedule */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 1 — Set Daily Schedule</h2>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Start Time</label>
            <div className="flex gap-2">
              <select
                className="input"
                value={startHour}
                onChange={e => setStartHour(parseInt(e.target.value))}
              >
                {Array.from({ length: 24 }, (_, i) => (
                  <option key={i} value={i}>{String(i).padStart(2, '0')}</option>
                ))}
              </select>
              <select
                className="input"
                value={startMinute}
                onChange={e => setStartMinute(parseInt(e.target.value))}
              >
                {[0, 15, 30, 45].map(m => (
                  <option key={m} value={m}>{String(m).padStart(2, '0')}</option>
                ))}
              </select>
            </div>
          </div>
        </div>

        <div className="mt-4">
          <label className="text-xs text-slate-400 font-semibold mb-2 block">Daily Active Duration</label>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
            {[60, 120, 180, 240].map(min => (
              <button
                key={min}
                onClick={() => setDurationMinutes(min)}
                className={'btn text-sm ' + (durationMinutes === min ? 'btn-primary' : 'btn-ghost')}
              >
                {min / 60} hour{min > 60 ? 's' : ''}
              </button>
            ))}
          </div>
          <div className="mt-3 text-sm text-slate-500">
            ⏰ Active window: <b>{String(startHour).padStart(2, '0')}:{String(startMinute).padStart(2, '0')}</b> → <b>{endTime}</b> (daily)
          </div>
        </div>
      </div>

      {/* STEP 2 — Emails */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 2 — Upload Bulk Emails (Excel / CSV)</h2>

        <input
          ref={fileRef}
          type="file"
          accept=".xlsx,.xls,.csv"
          onChange={e => e.target.files?.[0] && handleFile(e.target.files[0])}
          disabled={busy}
          className="input"
        />

        <div className="text-xs text-slate-500 mt-2">
          Excel format: 2 columns — <b>Company Name</b> + <b>Email</b> (3 lakh+ rows supported)
        </div>

        {fileStats && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
            <Stat label="TOTAL ROWS" value={fileStats.total} />
            <Stat label="VALID" value={fileStats.valid} color="#10b981" />
            <Stat label="INVALID" value={fileStats.invalid} color="#ef4444" />
            <Stat label="DUPLICATES" value={fileStats.duplicates} color="#f59e0b" />
          </div>
        )}

        {uploadProgress > 0 && uploadProgress < 100 && (
          <div className="mt-4">
            <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
              <div className="h-full bg-violet-500 transition-all" style={{ width: uploadProgress + '%' }} />
            </div>
            <div className="text-xs text-slate-500 mt-1">Uploading: {uploadProgress}%</div>
          </div>
        )}
      </div>

      {/* STEP 3 — Subject + HTML */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 3 — Email Content</h2>

        <div className="space-y-3">
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Subject</label>
            <input className="input" value={subject} onChange={e => setSubject(e.target.value)} />
            <div className="text-xs text-slate-500 mt-2 p-2 rounded bg-violet-50 border border-violet-200">
              Preview: <b>CONGRATULATIONS 🎉 {`{Company Name}`}</b>
            </div>
          </div>
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">HTML Body</label>
            <textarea
              className="input font-mono text-xs"
              rows={12}
              value={html}
              onChange={e => setHtml(e.target.value)}
            />
          </div>
        </div>
      </div>

      {/* LAUNCH */}
      <div className="card">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <div className="text-sm font-semibold">Ready to launch?</div>
            <div className="text-xs text-slate-500 mt-1">
              {rows.length} emails · {durationMinutes / 60}h window daily
            </div>
          </div>
          <button
            onClick={launch}
            disabled={busy || !rows.length || !subject.trim()}
            className="btn btn-primary"
            style={{ padding: '14px 32px', fontSize: 15 }}
          >
            {busy ? `⏳ Uploading ${uploadProgress}%` : `🚀 LAUNCH SCHEDULED CAMPAIGN`}
          </button>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 12 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>{value.toLocaleString()}</div>
    </div>
  );
}
