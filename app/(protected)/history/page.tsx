'use client';
import { useEffect, useState } from 'react';
export default function History() {
  const [list, setList] = useState<any[]>([]);
  useEffect(() => { fetch('/api/campaigns').then(r => r.json()).then(setList); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">📊 Campaign History</h1>
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">Campaign</th><th className="p-3">Total</th><th className="p-3">Sent</th><th className="p-3">Failed</th><th className="p-3">Spam</th><th className="p-3">Status</th><th className="p-3">Created</th><th className="p-3"></th></tr>
          </thead>
          <tbody>
            {list.map(c => (
              <tr key={c.id} className="border-t border-white/5">
                <td className="p-3">{c.name}</td>
                <td className="p-3">{c.totalCount}</td>
                <td className="p-3">{c.sentCount}</td>
                <td className="p-3">{c.failedCount}</td>
                <td className="p-3">{c.spamScore ?? '—'}</td>
                <td className="p-3">{c.status}</td>
                <td className="p-3 text-xs text-slate-500">{new Date(c.createdAt).toLocaleString()}</td>
                <td className="p-3"><a className="text-blue-400 underline" href={'/campaigns/' + c.id}>Open</a></td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={8} className="p-8 text-center text-slate-500">No campaigns.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
