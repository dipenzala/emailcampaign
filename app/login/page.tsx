'use client';
import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard/live';
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(''); setBusy(true);
    try {
      const r = await fetch('/api/auth/simple-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next);
      router.refresh();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />
      <div className="relative z-10 w-full max-w-md">
        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty flex items-center justify-center text-2xl">🔒</div>
            <h1 className="text-2xl font-semibold tracking-tight">EmailCampaign</h1>
            <p className="text-sm text-slate-400 mt-2">Enter password to continue</p>
          </div>
          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Password</label>
              <input
                type="password"
                required
                autoFocus
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="••••••••"
                className="input text-center text-lg tracking-widest"
                autoComplete="current-password"
              />
            </div>
            {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5 text-center">❌ {err}</div>}
            <button type="submit" disabled={busy || !password} className="btn btn-primary w-full py-3">
              {busy ? 'Verifying…' : '🔓 Unlock'}
            </button>
          </form>
          <div className="mt-6 text-xs text-slate-500 text-center">Authorized access only</div>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
