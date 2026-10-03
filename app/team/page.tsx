'use client';
import { useEffect, useState } from 'react';
export default function TeamPage() {
  const [members, setMembers] = useState<string[]>([]);
  useEffect(() => { fetch('/api/team').then(r => r.json()).then(j => setMembers(j.members ?? [])); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">👥 Team Access</h1>
      <p className="text-sm text-slate-400">
        Only these emails can login. This platform is invite-only.
      </p>
      <div className="card">
        <h2 className="font-semibold mb-3">Whitelisted Members ({members.length})</h2>
        {members.length === 0 ? (
          <p className="text-sm text-slate-400">
            ⚠️ No whitelist set. All emails can login (dev mode).<br />
            Set <code className="bg-white/5 px-1 rounded">ALLOWED_EMAILS</code> in Vercel env vars.
          </p>
        ) : (
          <ul className="space-y-2">
            {members.map(m => (
              <li key={m} className="flex items-center gap-3 p-3 rounded-lg bg-white/[0.02] border border-white/5">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center text-xs font-bold">
                  {m[0].toUpperCase()}
                </div>
                <span className="text-sm">{m}</span>
                <span className="ml-auto text-xs text-green-400">✓ Active</span>
              </li>
            ))}
          </ul>
        )}
        <div className="mt-4 text-xs text-slate-500">
          To add/remove members: Vercel → Settings → Environment Variables → <code className="bg-white/5 px-1 rounded">ALLOWED_EMAILS</code> (comma-separated) → Redeploy.
        </div>
      </div>
    </div>
  );
}
