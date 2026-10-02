'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

type ContactsSummary = { totalRows:number; valid:number; invalid:number; duplicates:number; suppressed:number; contacts:any[] };

export default function Home() {
  const [file, setFile] = useState<File|null>(null);
  const [summary, setSummary] = useState<ContactsSummary|null>(null);
  const [html, setHtml] = useState('');
  const [subject, setSubject] = useState('Hello from our team');
  const [campaignName, setCampaignName] = useState('Campaign ' + new Date().toISOString().slice(0,10));
  const [testTo, setTestTo] = useState('');
  const [senders, setSenders] = useState<any[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [showPreview, setShowPreview] = useState(false);
  const router = useRouter();

  useEffect(() => { fetch('/api/senders').then(r=>r.json()).then(setSenders); }, []);

  const upload = async () => {
    if (!file) return;
    setBusy(true); setMsg('');
    const fd = new FormData(); fd.append('file', file);
    const r = await fetch('/api/contacts/upload', { method:'POST', body: fd });
    const j = await r.json();
    if (r.ok) { setSummary(j); setMsg(`✅ ${j.valid} valid email addresses found.`); }
    else setMsg('❌ ' + (j.error ?? 'Upload failed'));
    setBusy(false);
  };

  const sendTest = async () => {
    setBusy(true); setMsg('');
    const r = await fetch('/api/test-email', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ to: testTo, subject, html }),
    });
    const j = await r.json();
    setMsg(r.ok ? '✅ Test email sent (id '+j.id+')' : '❌ ' + (j.error ?? 'Failed'));
    setBusy(false);
  };

  const startCampaign = async () => {
    if (!summary) return;
    setBusy(true); setMsg('');
    const r = await fetch('/api/campaigns', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        name: campaignName, subject, html,
        emails: summary.contacts.map(c => c.email),
      }),
    });
    const j = await r.json();
    if (!r.ok) { setMsg('❌ ' + JSON.stringify(j.error)); setBusy(false); return; }
    await fetch(`/api/campaigns/${j.id}/start`, { method:'POST' });
    router.push('/campaigns/' + j.id);
  };

  const connectedSenders = senders.filter(s => s.status === 'CONNECTED').length;
  const htmlOk = html.length > 30 && /<html|<body/i.test(html);
  const canStart = !!summary && summary.valid > 0 && htmlOk && connectedSenders > 0;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">📧 Email Campaign</h1>

      {msg && <div className="card text-sm">{msg}</div>}

      {/* STEP 1 */}
      <section className="card">
        <h2 className="font-semibold mb-3">STEP 1 — Load Contacts</h2>
        <div className="flex gap-3 items-center flex-wrap">
          <input type="file" accept=".xlsx,.xls,.csv"
            onChange={e => setFile(e.target.files?.[0] ?? null)}
            className="input max-w-xs" />
          <button className="btn btn-primary" disabled={!file || busy} onClick={upload}>
            {busy ? '…' : 'IMPORT EXCEL / CSV'}
          </button>
          <a href="/api/oauth/google/start?email=sheet" className="btn btn-ghost">Connect Google Sheet (OAuth)</a>
        </div>

        {summary && (
          <div className="mt-4 grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
            <Stat label="TOTAL ROWS" value={summary.totalRows} />
            <Stat label="VALID" value={summary.valid} accent="text-green-400" />
            <Stat label="INVALID" value={summary.invalid} accent="text-red-400" />
            <Stat label="DUPLICATES" value={summary.duplicates} accent="text-yellow-400" />
            <Stat label="SUPPRESSED" value={summary.suppressed} accent="text-orange-400" />
          </div>
        )}
        {summary && (
          <div className="mt-4 max-h-64 overflow-auto border border-slate-800 rounded-lg">
            <table className="w-full text-xs">
              <thead className="bg-slate-800/50 sticky top-0">
                <tr><th className="text-left p-2">Email</th><th className="text-left p-2">Name</th><th className="text-left p-2">Company</th></tr>
              </thead>
              <tbody>
                {summary.contacts.slice(0,200).map((c,i) => (
                  <tr key={i} className="border-t border-slate-800">
                    <td className="p-2">{c.email}</td><td className="p-2">{c.name}</td><td className="p-2">{c.company}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* STEP 2 */}
      <section className="card">
        <h2 className="font-semibold mb-3">STEP 2 — HTML Email</h2>
        <div className="space-y-3">
          <input className="input" placeholder="Subject" value={subject} onChange={e=>setSubject(e.target.value)} />
          <textarea className="input font-mono text-xs" rows={14}
            placeholder="<!DOCTYPE html>&#10;<html>…</html>"
            value={html} onChange={e=>setHtml(e.target.value)} />
          <div className="flex gap-3 flex-wrap">
            <button className="btn btn-ghost" onClick={()=>setShowPreview(true)} disabled={!html}>PREVIEW HTML</button>
            <input className="input max-w-xs" placeholder="Test email address" value={testTo} onChange={e=>setTestTo(e.target.value)} />
            <button className="btn btn-ghost" onClick={sendTest} disabled={!testTo || !html || busy}>SEND TEST</button>
          </div>
        </div>
      </section>

      {/* STEP 3 */}
      <section className="card">
        <h2 className="font-semibold mb-3">STEP 3 — Campaign</h2>
        <div className="space-y-3">
          <input className="input" placeholder="Campaign name" value={campaignName} onChange={e=>setCampaignName(e.target.value)} />
          <div className="text-sm text-slate-300">
            Connected senders: <b className={connectedSenders ? 'text-green-400' : 'text-red-400'}>{connectedSenders}</b>
            {' · '}Valid recipients: <b>{summary?.valid ?? 0}</b>
            {' · '}HTML: <b className={htmlOk ? 'text-green-400' : 'text-red-400'}>{htmlOk ? 'READY' : 'MISSING'}</b>
          </div>
          <div className="flex gap-3 flex-wrap">
            <button className="btn btn-primary" disabled={!canStart || busy} onClick={startCampaign}>
              {canStart ? 'START CAMPAIGN' : 'ADD CONTACTS + HTML EMAIL'}
            </button>
            <a href="/senders" className="btn btn-ghost">MANAGE SENDERS</a>
          </div>
        </div>
      </section>

      {showPreview && (
        <div className="fixed inset-0 bg-black/80 z-50 p-6 overflow-auto" onClick={()=>setShowPreview(false)}>
          <div className="bg-white text-black rounded-lg max-w-4xl mx-auto p-4" onClick={e=>e.stopPropagation()}>
            <div className="text-sm mb-2 flex justify-between"><b>Desktop Preview</b><button onClick={()=>setShowPreview(false)}>✕</button></div>
            <iframe className="w-full h-[70vh] border" sandbox="" srcDoc={html} />
            <div className="mt-4 text-sm">Mobile Preview (375px)</div>
            <iframe className="w-[375px] h-[500px] border mx-auto block" sandbox="" srcDoc={html} />
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value, accent='' }:{label:string;value:number;accent?:string}) {
  return (
    <div className="bg-slate-950 border border-slate-800 rounded-lg p-3">
      <div className="text-[10px] uppercase text-slate-400">{label}</div>
      <div className={`text-xl font-bold ${accent}`}>{value.toLocaleString()}</div>
    </div>
  );
}
