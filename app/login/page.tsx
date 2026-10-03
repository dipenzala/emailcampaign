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
  const [showPwd, setShowPwd] = useState(false);

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
    <div className="relative min-h-screen overflow-hidden">
      {/* Animated background */}
      <div className="aurora" aria-hidden />

      {/* Floating decorative blobs */}
      <div className="absolute top-20 left-10 w-32 h-32 rounded-full bg-gradient-to-br from-violet-400/40 to-pink-400/40 blur-2xl floaty" />
      <div className="absolute bottom-32 right-16 w-40 h-40 rounded-full bg-gradient-to-br from-blue-400/40 to-violet-400/40 blur-2xl floaty" style={{ animationDelay: '2s' }} />

      {/* Top-right credit */}
      <div className="absolute top-6 right-6 z-20 animate-fade">
        <div className="px-4 py-2 rounded-full bg-white/70 backdrop-blur-xl border border-violet-200/50 shadow-lg shadow-violet-500/10">
          <span className="text-xs font-medium text-slate-600">Created by</span>{' '}
          <span className="text-xs font-bold bg-gradient-to-r from-violet-600 to-pink-600 bg-clip-text text-transparent">DIPEN ZALA</span>
        </div>
      </div>

      {/* Main content */}
      <div className="relative z-10 min-h-screen flex items-center justify-center px-6 py-16">
        <div className="w-full max-w-md">

          {/* Logo */}
          <div className="text-center mb-8 animate-in">
            <div className="inline-block relative">
              <div className="absolute inset-0 bg-gradient-to-br from-violet-500 to-pink-500 rounded-3xl blur-2xl opacity-40 glow-pulse" />
              <div className="relative w-20 h-20 rounded-3xl bg-gradient-to-br from-violet-500 via-fuchsia-500 to-pink-500 flex items-center justify-center shadow-2xl shadow-violet-500/40 floaty">
                <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </div>
            </div>
            <h1 className="mt-6 text-4xl font-bold tracking-tight text-slate-900">
              Email<span className="gradient-text">Campaign</span>
            </h1>
            <p className="mt-2 text-sm text-slate-500">Premium email marketing platform</p>
          </div>

          {/* Card */}
          <div className="card !p-8 animate-in-slow shadow-2xl shadow-violet-500/10">

            {checking ? (
              <div className="text-center text-slate-400 py-8 flex flex-col items-center gap-3">
                <div className="w-8 h-8 border-2 border-violet-500 border-t-transparent rounded-full slow-spin" />
                Loading…
              </div>
            ) : setupNeeded ? (
              <>
                <div className="text-center mb-6">
                  <h2 className="text-2xl font-bold text-slate-900">Initial Setup</h2>
                  <p className="text-sm text-slate-500 mt-1">Create the first admin account</p>
                </div>
                <SetupForm onDone={() => setSetupNeeded(false)} />
              </>
            ) : (
              <>
                <div className="text-center mb-6">
                  <h2 className="text-2xl font-bold text-slate-900">Welcome back</h2>
                  <p className="text-sm text-slate-500 mt-1">Sign in to continue</p>
                </div>

                <form onSubmit={submit} className="space-y-4">
                  <div>
                    <label className="text-xs font-medium text-slate-600 mb-1.5 block uppercase tracking-wide">Username</label>
                    <div className="relative">
                      <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400">
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        required
                        value={username}
                        onChange={e => setUsername(e.target.value)}
                        placeholder="your-username"
                        className="input !pl-10"
                        autoComplete="username"
                        autoFocus
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-slate-600 mb-1.5 block uppercase tracking-wide">Password</label>
                    <div className="relative">
                      <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400">
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                      </span>
                      <input
                        type={showPwd ? 'text' : 'password'}
                        required
                        value={password}
                        onChange={e => setPassword(e.target.value)}
                        placeholder="••••••••"
                        className="input !pl-10 !pr-10"
                        autoComplete="current-password"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPwd(!showPwd)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700"
                      >
                        {showPwd ? (
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                          </svg>
                        ) : (
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          </svg>
                        )}
                      </button>
                    </div>
                  </div>

                  {err && (
                    <div className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-2.5 animate-in flex items-start gap-2">
                      <span className="text-base">⚠️</span>
                      <span>{err}</span>
                    </div>
                  )}

                  <button type="submit" disabled={busy} className="btn btn-primary w-full py-3 !text-base">
                    {busy ? (
                      <span className="flex items-center gap-2">
                        <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full slow-spin" />
                        Signing in…
                      </span>
                    ) : (
                      <>Sign in <span>→</span></>
                    )}
                  </button>
                </form>
              </>
            )}
          </div>

          {/* Bottom info */}
          <div className="text-center mt-8 space-y-3 animate-fade">
            <div className="flex items-center justify-center gap-4 text-xs text-slate-500">
              <span className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
                Secure
              </span>
              <span className="w-px h-3 bg-slate-300" />
              <span>Invite-only</span>
              <span className="w-px h-3 bg-slate-300" />
              <span>OAuth 2.0</span>
            </div>

            <div className="pt-4 border-t border-slate-200">
              <p className="text-xs text-slate-400">
                © {new Date().getFullYear()} EmailCampaign · <span className="font-semibold text-slate-600">Created by DIPEN ZALA</span>
              </p>
            </div>
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
      <div className="bg-violet-50 border border-violet-200 rounded-xl px-4 py-3 text-xs text-violet-700 flex items-start gap-2">
        <span className="text-base">👋</span>
        <span>First-time setup. Create your admin account to get started.</span>
      </div>

      <div>
        <label className="text-xs font-medium text-slate-600 mb-1.5 block uppercase tracking-wide">Admin Username</label>
        <input type="text" required value={username} onChange={e => setUsername(e.target.value)} placeholder="admin" className="input" autoFocus />
      </div>

      <div>
        <label className="text-xs font-medium text-slate-600 mb-1.5 block uppercase tracking-wide">Password (min 8 chars)</label>
        <input type="password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" className="input" />
      </div>

      <div>
        <label className="text-xs font-medium text-slate-600 mb-1.5 block uppercase tracking-wide">Setup Key</label>
        <input type="text" required value={setupKey} onChange={e => setSetupKey(e.target.value)} placeholder="from Vercel env" className="input" />
        <p className="text-xs text-slate-500 mt-1.5">
          Vercel → Environment Variables → <code className="bg-slate-100 px-1.5 py-0.5 rounded text-slate-700">ADMIN_SETUP_KEY</code>
        </p>
      </div>

      {err && (
        <div className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-2.5">{err}</div>
      )}

      <button type="submit" disabled={busy} className="btn btn-primary w-full py-3 !text-base">
        {busy ? 'Creating…' : 'Create Admin →'}
      </button>
    </form>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-400">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
