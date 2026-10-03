'use client';
import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
export default function CampaignLive() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [s, setS] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');
  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${id}/status`).then(r => r.json()).then(j => setS({ ...j.counts, status: j.campaign.status, ts: j.updatedAt }));
    load();
    const iv = setInterval(load, 2000);
    return () => clearInterval(iv);
  }, [id]);
  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${id}/recipients?status=${filter}`).then(r => r.json()).then(setRecipients);
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, [id, filter]);
  const act = async (a: 'pause'|'resume'|'stop') => {
    if (a === 'stop' && !confirm('Stop campaign?')) return;
    await fetch(`/api/campaigns/${id}/${a}`, { method: 'POST' });
  };
  const progress = s?.progress ?? 0;
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 flex-wrap">
        <h1 className="text-2xl font-bold">Status: {s?.status ?? '...'}</h1>
        <span className="text-xs px-2 py-1 rounded bg-slate-800">LIVE</span>
        <div className="flex gap-2 ml-auto">
          {s?.status === 'RUNNING' && <button className="btn btn-ghost" onClick={() => act('pause')}>PAUSE</button>}
          {s?.status === 'PAUSED' && <button className="btn btn-primary" onClick={() => act('resume')}>RESUME</button>}
          {s?.status !== 'COMPLETED' && s?.status !== 'STOPPED' && <button className="btn btn-danger" onClick={() => act('stop')}>STOP</button>}
        </div>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        {[['TOTAL',s?.total,''],['SENT',s?.sent,'text-blue-400'],['DELIVERED',s?.delivered,'text-green-400'],['FAILED',s?.failed,'text-red-400'],['BOUNCED',s?.bounced,'text-orange-400'],['PENDING',s?.pending,'text-yellow-400'],['SUPPRESSED',s?.suppressed,'text-slate-400']].map(([l,v,c]) => (
          <div key={l as string} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
            <div className="text-[10px] uppercase text-slate-400">{l}</div>
            <div className={`text-xl font-bold ${c}`}>{(v ?? 0).toLocaleString()}</div>
          </div>
        ))}
      </div>
      <div className="card">
        <div className="flex justify-between text-sm mb-2"><span>Progress</span><b>{progress}%</b></div>
        <div className="w-full h-3 bg-slate-800 rounded overflow-hidden"><div className="h-full bg-blue-500 transition-all" style={{ width: progress + '%' }} /></div>
      </div>
      <div className="card">
        <div className="flex gap-2 flex-wrap mb-3">
          {['ALL','QUEUED','PROCESSING','SENT','DELIVERED','FAILED','BOUNCED','SUPPRESSED'].map(f => (
            <button key={f} onClick={() => setFilter(f)} className={'text-xs px-3 py-1 rounded ' + (filter === f ? 'bg-blue-600' : 'bg-slate-800 hover:bg-slate-700')}>{f}</button>
          ))}
        </div>
        <div className="max-h-96 overflow-auto">
          <table className="w-full text-xs">
            <thead className="text-slate-400 text-left sticky top-0 bg-slate-900"><tr><th className="p-2">Email</th><th>Name</th><th>Status</th><th>Error</th></tr></thead>
            <tbody>
              {recipients.map(r => (
                <tr key={r.id} className="border-t border-slate-800">
                  <td className="p-2">{r.email}</td><td>{r.name}</td>
                  <td className={r.status === 'DELIVERED' ? 'text-green-400' : r.status === 'SENT' ? 'text-blue-400' : r.status === 'FAILED' || r.status === 'BOUNCED' ? 'text-red-400' : r.status === 'SUPPRESSED' ? 'text-slate-500' : 'text-yellow-400'}>{r.status}</td>
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
