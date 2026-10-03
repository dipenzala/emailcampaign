'use client';
import { useState, Suspense, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [setupNeeded, setSetupNeeded] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    fetch('/api/auth/setup')
      .then(r => r.json())
      .then(j => setSetupNeeded(j.setupNeeded))
      .catch(() => {})
      .finally(() => setChecking(false));
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      const r = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
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
        <Link href="/" className="inline-flex items-center gap-2 mb-8 text-sm text-slate-400 hover:text-white transition">
          ← Back to home
        </Link>

        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty" />
            <h1 className="text-2xl font-semibold tracking-tight">
              {setupNeeded ? 'Initial Setup' : 'Team Login'}
            </h1>
            <p className="text-sm text-slate-400 mt-2">
              {setupNeeded
                ? 'Create the first admin account'
                : 'Sign in with your team credentials'}
            </p>
          </div>

          {checking ? (
            <div className="text-center text-slate-500 text-sm py-6">Loading…</div>
          ) : setupNeeded ? (
            <SetupForm onDone={() => setSetupNeeded(false)} />
          ) : (
            <form onSubmit={submit} className="space-y-4">
              <div>
                <label className="text-xs text-slate-400 mb-1.5 block">Username</label>
                <input
                  type="text"
                  required
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  placeholder="your-username"
                  className="input"
                  autoComplete="username"
                  autoFocus
                />
              </div>
              <div>
                <label className="text-xs text-slate-400 mb-1.5 block">Password</label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="input"
                  autoComplete="current-password"
                />
              </div>

              {err && (
                <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                  {err}
                </div>
              )}

              <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">
                {busy ? 'Signing in…' : 'Sign in →'}
              </button>
            </form>
          )}

          <div className="mt-6 text-xs text-slate-500 text-center leading-relaxed">
            🔒 Invite-only platform. Access is managed by the admin.
          </div>
        </div>
      </div>
    </div>
  );
}

function SetupForm({ onDone }: { onDone: () => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [setupKey, setSetupKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      const r = await fetch('/api/auth/setup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, setupKey }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Setup failed');
      onDone();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl px-4 py-3 text-xs text-blue-300">
        👋 First time setup. Create your admin account.
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Admin Username</label>
        <input type="text" required value={username} onChange={e => setUsername(e.target.value)} placeholder="admin" className="input" />
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Password (min 8 chars)</label>
        <input type="password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" className="input" />
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Setup Key (from Vercel env)</label>
        <input type="text" required value={setupKey} onChange={e => setSetupKey(e.target.value)} placeholder="ADMIN_SETUP_KEY value" className="input" />
        <p className="text-xs text-slate-500 mt-1">
          Vercel → Environment Variables → <code className="bg-white/5 px-1 rounded">ADMIN_SETUP_KEY</code>
        </p>
      </div>
      {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">{err}</div>}
      <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">
        {busy ? 'Creating…' : 'Create Admin →'}
      </button>
    </form>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
