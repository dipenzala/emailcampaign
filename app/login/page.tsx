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
    <div className="relative min-h-screen overflow-hidden flex items-center justify-center px-6 py-16">
      {/* Premium background */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-[10%] left-[15%] w-96 h-96 rounded-full bg-[#0071e3]/15 blur-[120px] float-slow" />
        <div className="absolute bottom-[10%] right-[15%] w-[500px] h-[500px] rounded-full bg-[#5e5ce6]/10 blur-[140px] float" style={{ animationDelay: '2s' }} />
      </div>

      {/* Top-right credit */}
      <div className="absolute top-6 right-6 z-20 fade-up">
        <div className="px-4 py-2 rounded-full bg-white/70 backdrop-blur-xl border border-black/[0.06] shadow-sm">
          <span className="text-xs text-[#86868b]">Created by</span>{' '}
          <span className="text-xs font-semibold text-[#0071e3]">DIPEN ZALA</span>
        </div>
      </div>

      <div className="relative z-10 w-full max-w-[400px]">
        {/* Logo */}
        <div className="text-center mb-10 fade-up">
          <div className="inline-block relative">
            <div className="absolute inset-0 bg-[#0071e3] rounded-2xl blur-2xl opacity-30" />
            <div className="relative w-16 h-16 rounded-2xl bg-[#0071e3] flex items-center justify-center shadow-xl shadow-[#0071e3]/30 float-slow">
              <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
          <h1 className="mt-6 text-3xl font-semibold tracking-tight text-[#1d1d1f]">
            Email<span className="gradient-text">Campaign</span>
          </h1>
          <p className="mt-2 text-sm text-[#86868b]">Premium email platform</p>
        </div>

        {/* Card */}
        <div className="card !p-8 md:!p-10 !rounded-3xl fade-up fade-up-delay-1 shadow-2xl shadow-black/[0.08]">

          {checking ? (
            <div className="text-center text-[#86868b] py-12 flex flex-col items-center gap-3">
              <div className="w-6 h-6 border-2 border-[#0071e3] border-t-transparent rounded-full animate-spin" />
              <span className="text-sm">Loading…</span>
            </div>
          ) : setupNeeded ? (
            <>
              <div className="text-center mb-8">
                <h2 className="text-2xl font-semibold text-[#1d1d1f]">Initial Setup</h2>
                <p className="text-sm text-[#86868b] mt-1">Create your admin account</p>
              </div>
              <SetupForm onDone={() => setSetupNeeded(false)} />
            </>
          ) : (
            <>
              <div className="text-center mb-8">
                <h2 className="text-2xl font-semibold text-[#1d1d1f]">Welcome back</h2>
                <p className="text-sm text-[#86868b] mt-1">Sign in to continue</p>
              </div>

              <form onSubmit={submit} className="space-y-4">
                <div>
                  <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide">Username</label>
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
                  <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide">Password</label>
                  <div className="relative">
                    <input
                      type={showPwd ? 'text' : 'password'}
                      required
                      value={password}
                      onChange={e => setPassword(e.target.value)}
                      placeholder="••••••••"
                      className="input !pr-12"
                      autoComplete="current-password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPwd(!showPwd)}
                      className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[#86868b] hover:text-[#1d1d1f] transition-colors"
                      tabIndex={-1}
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
                  <div className="text-sm text-[#ff3b30] bg-[#ff3b30]/[0.06] border border-[#ff3b30]/20 rounded-xl px-4 py-3 flex items-start gap-2 fade-up">
                    <svg className="w-4 h-4 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                    <span>{err}</span>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={busy}
                  className="btn btn-primary w-full !py-3 !text-base !mt-2"
                >
                  {busy ? (
                    <span className="flex items-center gap-2">
                      <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                      Signing in…
                    </span>
                  ) : (
                    <>
                      Sign in
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                      </svg>
                    </>
                  )}
                </button>
              </form>
            </>
          )}
        </div>

        {/* Trust badges */}
        <div className="mt-6 flex items-center justify-center gap-5 text-xs text-[#86868b] fade-up fade-up-delay-2">
          <span className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-[#30d158]" />
            Secure
          </span>
          <span className="w-px h-3 bg-black/10" />
          <span>Invite-only</span>
          <span className="w-px h-3 bg-black/10" />
          <span>OAuth 2.0</span>
        </div>

        <div className="mt-8 text-center fade-up fade-up-delay-3">
          <p className="text-xs text-[#86868b]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
          </p>
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
      <div className="bg-[#0071e3]/[0.06] border border-[#0071e3]/15 rounded-xl px-4 py-3 text-xs text-[#0071e3] flex items-start gap-2">
        <svg className="w-4 h-4 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
        </svg>
        <span>First-time setup. Create your admin account to get started.</span>
      </div>

      <div>
        <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide">Admin Username</label>
        <input type="text" required value={username} onChange={e => setUsername(e.target.value)} placeholder="admin" className="input" autoFocus />
      </div>

      <div>
        <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide">Password (min 8 chars)</label>
        <input type="password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" className="input" />
      </div>

      <div>
        <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide">Setup Key</label>
        <input type="text" required value={setupKey} onChange={e => setSetupKey(e.target.value)} placeholder="from Vercel env" className="input" />
        <p className="text-xs text-[#86868b] mt-2">
          Vercel → Environment Variables → <code className="bg-black/[0.05] px-1.5 py-0.5 rounded text-[#424245] text-[11px]">ADMIN_SETUP_KEY</code>
        </p>
      </div>

      {err && (
        <div className="text-sm text-[#ff3b30] bg-[#ff3b30]/[0.06] border border-[#ff3b30]/20 rounded-xl px-4 py-3">{err}</div>
      )}

      <button type="submit" disabled={busy} className="btn btn-primary w-full !py-3 !text-base">
        {busy ? 'Creating…' : 'Create Admin →'}
      </button>
    </form>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-[#86868b]">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
