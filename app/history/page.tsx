'use client';
import { useEffect, useState } from 'react';
export default function History() {
  const [list, setList] = useState<any[]>([]);
  useEffect(()=>{ fetch('/api/campaigns').then(r=>r.json()).then(setList); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">📊 Campaign History</h1>
      <div className="card">
        <table className="w-full text-sm">
          <thead className="text-slate-400 text-left">
            <tr><th className="p-2">Campaign</th><th>Total</th><th>Sent</th><th>Failed</th><th>Status</th><th>Created</th><th></th></tr>
          </thead>
          <tbody>
            {list.map(c => (
              <tr key={c.id} className="border-t border-slate-800">
                <td className="p-2">{c.name}</td>
                <td>{c.totalCount}</td><td>{c.sentCount}</td><td>{c.failedCount}</td>
                <td>{c.status}</td>
                <td>{new Date(c.createdAt).toLocaleString()}</td>
                <td><a className="text-blue-400 underline" href={'/campaigns/'+c.id}>Open</a></td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={7} className="p-6 text-center text-slate-500">No campaigns yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
