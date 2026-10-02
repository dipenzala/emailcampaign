'use client';
import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';

export default function CampaignLive() {
  const params = useParams<{ id:string }>();
  const id = params.id;
  const [s, setS] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');

  useEffect(() => {
    const es = new EventSource(`/api/campaigns/${id}/stream`);
    es.onmessage = e => { try { setS(JSON.parse(e.data)); } catch {} };
    es.onerror = () => {};
    return () => es.close();
  }, [id]);

  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${id}/recipients?status=${filter}`).then(r=>r.json()).then(setRecipients);
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, [id, filter]);

  const act = async (a:'pause'|'resume'|'stop') => {
    if (a === 'stop' && !confirm('Stop campaign? Pending jobs will be removed.')) return;
    await fetch(`/api/campaigns/${id}/${a}`, { method:'POST' });
  };

  const status = s?.status ?? 'LOADING';
  const progress = s?.progress ?? 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 flex-wrap">
        <h1 className="text-2xl font-bold">Campaign Status: {status}</h1>
        <span className="text-xs px-2 py-1 rounded bg-slate-800">LIVE</span>
        <span className="text-xs text-slate-400">Last update: {s ? new Date(s.ts).toLocaleTimeString() : '—'}</span>
        <div className="flex gap-2 ml-auto">
          {status === 'RUNNING' && <button className="btn btn-ghost" onClick={()=>act('pause')}>PAUSE</button>}
          {status === 'PAUSED' && <button className="btn btn-primary" onClick={()=>act('resume')}>RESUME</button>}
          {status !== 'COMPLETED' && status !== 'STOPPED' && <button className="btn btn-danger" onClick={()=>act('stop')}>STOP</button>}
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        <KPI label="TOTAL" value={s?.total ?? 0} />
        <KPI label="SENT" value={s?.sent ?? 0} accent="text-blue-400" />
        <KPI label="DELIVERED" value={s?.delivered ?? 0} accent="text-green-400" />
        <KPI label="FAILED" value={s?.failed ?? 0} accent="text-red-400" />
        <KPI label="BOUNCED" value={s?.bounced ?? 0} accent="text-orange-400" />
        <KPI label="PENDING" value={s?.pending ?? 0} accent="text-yellow-400" />
        <KPI label="SUPPRESSED" value={s?.suppressed ?? 0} accent="text-slate-400" />
      </div>

      <div className="card">
        <div className="flex justify-between text-sm mb-2"><span>Progress</span><b>{progress}%</b></div>
        <div className="w-full h-3 bg-slate-800 rounded overflow-hidden">
          <div className="h-full bg-blue-500 transition-all" style={{ width: progress + '%' }} />
        </div>
        <p className="text-xs text-slate-400 mt-2">"SENT" means provider accepted. "DELIVERED" only when reliable delivery info is available.</p>
      </div>

      <div className="card">
        <div className="flex gap-2 flex-wrap mb-3">
          {['ALL','QUEUED','PROCESSING','SENT','DELIVERED','FAILED','BOUNCED','SUPPRESSED'].map(f => (
            <button key={f} onClick={()=>setFilter(f)}
              className={'text-xs px-3 py-1 rounded ' + (filter === f ? 'bg-blue-600' : 'bg-slate-800 hover:bg-slate-700')}>{f}</button>
          ))}
        </div>
        <div className="max-h-96 overflow-auto">
          <table className="w-full text-xs">
            <thead className="text-slate-400 text-left sticky top-0 bg-slate-900">
              <tr><th className="p-2">Email</th><th>Name</th><th>Status</th><th>Error</th></tr>
            </thead>
            <tbody>
              {recipients.map(r => (
                <tr key={r.id} className="border-t border-slate-800">
                  <td className="p-2">{r.email}</td>
                  <td>{r.name}</td>
                  <td className={
                    r.status === 'DELIVERED' ? 'text-green-400' :
                    r.status === 'SENT' ? 'text-blue-400' :
                    r.status === 'FAILED' || r.status === 'BOUNCED' ? 'text-red-400' :
                    r.status === 'SUPPRESSED' ? 'text-slate-500' : 'text-yellow-400'
                  }>{r.status}</td>
                  <td className="text-slate-500 truncate max-w-xs">{r.error ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function KPI({ label, value, accent='' }:{label:string;value:number;accent?:string}) {
  return (
    <div className="bg-slate-950 border border-slate-800 rounded-lg p-3">
      <div className="text-[10px] uppercase text-slate-400">{label}</div>
      <div className={`text-xl font-bold ${accent}`}>{(value ?? 0).toLocaleString()}</div>
    </div>
  );
}
