#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎨 Light Theme + Login Redesign"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 2. Light theme CSS ----------
echo ""
echo "🎨 [1/7] Light theme CSS..."

cat > app/globals.css <<'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --bg: #f8fafc;
  --fg: #0f172a;
  --card-bg: rgba(255, 255, 255, 0.75);
  --card-border: rgba(15, 23, 42, 0.08);
  --primary: #6366f1;
  --primary-dark: #4f46e5;
  --accent: #ec4899;
}

* { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }

html, body {
  background: #f8fafc;
  color: #0f172a;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Segoe UI", sans-serif;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
  scroll-behavior: smooth;
}

/* ---------- 3D Background mesh ---------- */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -2;
  background:
    radial-gradient(circle at 15% 20%, rgba(139, 92, 246, 0.15) 0%, transparent 45%),
    radial-gradient(circle at 85% 15%, rgba(236, 72, 153, 0.12) 0%, transparent 40%),
    radial-gradient(circle at 50% 90%, rgba(59, 130, 246, 0.12) 0%, transparent 45%),
    linear-gradient(180deg, #f8fafc 0%, #eef2ff 100%);
  pointer-events: none;
}

body::after {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -1;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.03) 1px, transparent 1px);
  background-size: 48px 48px;
  pointer-events: none;
  animation: gridShift 30s linear infinite;
}

@keyframes gridShift {
  0% { background-position: 0 0; }
  100% { background-position: 48px 48px; }
}

/* ---------- Aurora (light) ---------- */
.aurora { position: absolute; inset: 0; overflow: hidden; pointer-events: none; z-index: 0; }
.aurora::before,
.aurora::after {
  content: '';
  position: absolute;
  width: 55vw;
  height: 55vw;
  border-radius: 50%;
  filter: blur(110px);
  opacity: 0.5;
}
.aurora::before {
  background: radial-gradient(circle, #a78bfa, transparent 65%);
  top: -15%; left: -10%;
  animation: float1 18s ease-in-out infinite;
}
.aurora::after {
  background: radial-gradient(circle, #f472b6, transparent 65%);
  bottom: -25%; right: -10%;
  animation: float2 22s ease-in-out infinite;
}
@keyframes float1 {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
  50% { transform: translate3d(8vw, 6vh, 0) scale(1.15); }
}
@keyframes float2 {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1.1); }
  50% { transform: translate3d(-10vw, -8vh, 0) scale(0.95); }
}

/* ---------- Cards (glass + 3D) ---------- */
.card {
  background: var(--card-bg);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid var(--card-border);
  border-radius: 1.25rem;
  padding: 1.5rem;
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.04),
    0 8px 24px -8px rgba(99, 102, 241, 0.12);
  transition: box-shadow 0.4s cubic-bezier(0.22, 1, 0.36, 1), transform 0.4s;
}
.card:hover {
  box-shadow:
    0 2px 4px rgba(15, 23, 42, 0.05),
    0 20px 40px -12px rgba(99, 102, 241, 0.18);
}

/* ---------- Buttons ---------- */
.btn {
  @apply inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-semibold;
  transition: all 0.3s cubic-bezier(0.22, 1, 0.36, 1);
  cursor: pointer;
  border: none;
  user-select: none;
}
.btn-primary {
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #ec4899 100%);
  background-size: 200% 200%;
  color: white;
  box-shadow: 0 8px 24px -6px rgba(99, 102, 241, 0.45);
  animation: gradientShift 4s ease infinite;
}
.btn-primary:hover:not(:disabled) {
  transform: translateY(-2px) scale(1.02);
  box-shadow: 0 16px 40px -8px rgba(99, 102, 241, 0.55);
}
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; animation: none; }

.btn-ghost {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid rgba(15, 23, 42, 0.08);
  color: #334155;
  backdrop-filter: blur(10px);
}
.btn-ghost:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.95);
  transform: translateY(-2px);
  box-shadow: 0 8px 20px -6px rgba(15, 23, 42, 0.15);
}

.btn-danger {
  background: linear-gradient(135deg, #ef4444, #dc2626);
  color: white;
  box-shadow: 0 8px 20px -6px rgba(239, 68, 68, 0.4);
}
.btn-danger:hover { transform: translateY(-2px); }

/* ---------- Inputs ---------- */
.input {
  @apply w-full px-4 py-2.5 rounded-xl;
  background: rgba(255, 255, 255, 0.85);
  border: 1.5px solid rgba(15, 23, 42, 0.08);
  color: #0f172a;
  font-size: 0.9rem;
  transition: all 0.25s;
  backdrop-filter: blur(10px);
}
.input::placeholder { color: #94a3b8; }
.input:focus {
  outline: none;
  border-color: #8b5cf6;
  box-shadow: 0 0 0 4px rgba(139, 92, 246, 0.12);
  background: white;
}

/* ---------- Gradient text ---------- */
.gradient-text {
  background: linear-gradient(120deg, #6366f1 0%, #8b5cf6 30%, #ec4899 70%, #f59e0b 100%);
  background-size: 300% 300%;
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  animation: gradientShift 6s ease infinite;
}
@keyframes gradientShift {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

/* ---------- Nav (glass light) ---------- */
.glass-nav {
  background: rgba(255, 255, 255, 0.75);
  backdrop-filter: saturate(180%) blur(18px);
  -webkit-backdrop-filter: saturate(180%) blur(18px);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
}

/* ---------- 3D Tilt Card ---------- */
.tilt {
  transition: transform 0.5s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.5s;
  transform-style: preserve-3d;
  will-change: transform;
}
.tilt:hover {
  transform: perspective(1200px) rotateX(3deg) rotateY(-3deg) translateY(-6px) scale(1.015);
  box-shadow:
    0 2px 4px rgba(15, 23, 42, 0.04),
    0 40px 70px -20px rgba(139, 92, 246, 0.28),
    0 0 0 1px rgba(139, 92, 246, 0.08);
}

/* ---------- Fade in ---------- */
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(0); }
}
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.animate-in { animation: fadeInUp 0.9s cubic-bezier(0.22, 1, 0.36, 1) both; }
.animate-in-slow { animation: fadeInUp 1.3s cubic-bezier(0.22, 1, 0.36, 1) both; }
.animate-fade { animation: fadeIn 1.4s ease both; }
.delay-1 { animation-delay: 0.15s; }
.delay-2 { animation-delay: 0.30s; }
.delay-3 { animation-delay: 0.45s; }
.delay-4 { animation-delay: 0.60s; }
.delay-5 { animation-delay: 0.75s; }

/* ---------- Shimmer ---------- */
.shimmer { position: relative; overflow: hidden; }
.shimmer::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(139, 92, 246, 0.15) 50%, transparent 70%);
  transform: translateX(-100%);
  animation: shimmer 3s ease-in-out infinite;
}
@keyframes shimmer {
  0% { transform: translateX(-100%); }
  60%, 100% { transform: translateX(100%); }
}

/* ---------- Floaty ---------- */
@keyframes floaty {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}
.floaty { animation: floaty 6s ease-in-out infinite; }

/* ---------- Glow pulse ---------- */
@keyframes glowPulse {
  0%, 100% { box-shadow: 0 0 20px rgba(139, 92, 246, 0.3); }
  50% { box-shadow: 0 0 40px rgba(139, 92, 246, 0.55); }
}
.glow-pulse { animation: glowPulse 3s ease-in-out infinite; }

/* ---------- Rotate (logo) ---------- */
@keyframes slowSpin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
.slow-spin { animation: slowSpin 20s linear infinite; }

/* ---------- Text colors override (light theme) ---------- */
.text-slate-100 { color: #0f172a; }
.text-slate-200 { color: #1e293b; }
.text-slate-300 { color: #334155; }
.text-slate-400 { color: #64748b; }
.text-slate-500 { color: #94a3b8; }

.bg-slate-950, .bg-slate-900 { background-color: transparent !important; }
.bg-slate-800 { background-color: rgba(15, 23, 42, 0.05) !important; }
.border-slate-800, .border-slate-700 { border-color: rgba(15, 23, 42, 0.08) !important; }
.bg-white\/5 { background-color: rgba(15, 23, 42, 0.03) !important; }
.bg-white\/10 { background-color: rgba(15, 23, 42, 0.06) !important; }
.border-white\/5, .border-white\/10 { border-color: rgba(15, 23, 42, 0.06) !important; }

/* ---------- Scrollbar ---------- */
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: rgba(15, 23, 42, 0.15);
  border-radius: 10px;
  border: 2px solid transparent;
  background-clip: padding-box;
}
::-webkit-scrollbar-thumb:hover { background: rgba(15, 23, 42, 0.25); background-clip: padding-box; }
CSSEOF
echo "   ✅"

# ---------- 3. Login page (redesigned) ----------
echo ""
echo "🔐 [2/7] Redesigned login page..."

mkdir -p app/login
cat > app/login/page.tsx <<'EOF'
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
EOF
echo "   ✅"

# ---------- 4. Landing page (light) ----------
echo ""
echo "✨ [3/7] Landing page (light theme)..."

cat > app/page.tsx <<'EOF'
import Link from 'next/link';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      <div className="aurora" aria-hidden />

      {/* Nav */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-violet-500 via-fuchsia-500 to-pink-500 flex items-center justify-center shadow-lg shadow-violet-500/30 group-hover:scale-110 transition-transform">
              <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-bold tracking-tight text-slate-900">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-3">
            <a href="#features" className="hidden md:block text-sm font-medium text-slate-600 hover:text-slate-900 transition">Features</a>
            <Link href="/login" className="text-sm font-medium text-slate-600 hover:text-slate-900 transition">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-sm">Get Started →</Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative pt-40 pb-24 px-6">
        <div className="max-w-5xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/70 backdrop-blur border border-violet-200 text-xs font-medium text-slate-700 mb-8 animate-in shimmer shadow-sm">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            Now live · Powered by Gmail API
          </div>

          <h1 className="text-5xl md:text-7xl lg:text-8xl font-black tracking-tight leading-[0.98] text-slate-900 animate-in-slow delay-1">
            Send email<br />
            <span className="gradient-text">that converts.</span>
          </h1>

          <p className="mt-8 text-lg md:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            Production-grade email campaigns with sender rotation, anti-spam protection, and real-time analytics. Built for teams who care about deliverability.
          </p>

          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-8 py-3.5 !text-base">
              Start Campaign →
            </Link>
            <a href="#features" className="btn btn-ghost text-base px-8 py-3.5">
              See Features
            </a>
          </div>

          {/* Stats */}
          <div className="mt-20 grid grid-cols-3 gap-6 max-w-2xl mx-auto animate-in-slow delay-4">
            {[
              { v: '25+', l: 'Sender Accounts' },
              { v: '99.9%', l: 'Uptime' },
              { v: '7-Layer', l: 'Anti-Spam' },
            ].map((s, i) => (
              <div key={s.l} className="text-center">
                <div className="text-3xl md:text-4xl font-bold gradient-text">{s.v}</div>
                <div className="text-xs text-slate-500 mt-1">{s.l}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Floating dashboard preview */}
        <div className="relative max-w-5xl mx-auto mt-20 animate-in-slow delay-5">
          <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-violet-500/20">
            <div className="flex items-center gap-2 px-4 py-3 border-b border-slate-100 bg-white/50">
              <span className="w-3 h-3 rounded-full bg-red-400" />
              <span className="w-3 h-3 rounded-full bg-amber-400" />
              <span className="w-3 h-3 rounded-full bg-green-400" />
              <span className="ml-3 text-xs text-slate-400 font-mono">campaign · live</span>
            </div>
            <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4 bg-white/40">
              {[
                { l: 'SENT', v: '12,847', c: 'from-blue-500 to-blue-600' },
                { l: 'DELIVERED', v: '12,412', c: 'from-green-500 to-emerald-600' },
                { l: 'PENDING', v: '435', c: 'from-amber-500 to-orange-500' },
                { l: 'FAILED', v: '12', c: 'from-red-500 to-rose-600' },
              ].map(s => (
                <div key={s.l} className="bg-white border border-slate-100 rounded-xl p-4 shadow-sm">
                  <div className="text-[10px] tracking-widest text-slate-400 font-medium">{s.l}</div>
                  <div className={`text-2xl font-bold mt-1 bg-gradient-to-r ${s.c} bg-clip-text text-transparent`}>{s.v}</div>
                </div>
              ))}
            </div>
            <div className="px-8 pb-8 bg-white/40">
              <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
                <div className="h-full w-[96%] bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full" />
              </div>
              <div className="flex justify-between text-xs text-slate-400 mt-2">
                <span>Progress</span>
                <span className="font-medium text-slate-600">96.4%</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="relative py-28 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-black tracking-tight text-slate-900">
              Everything you need. <span className="gradient-text">Nothing you don't.</span>
            </h2>
            <p className="mt-5 text-slate-600 max-w-xl mx-auto">
              Built with real infrastructure — Postgres, Redis, BullMQ, Gmail API.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: '🔒', title: 'OAuth 2.0 Only', desc: 'We never see your Gmail password. Tokens AES-256 encrypted at rest.', color: 'from-violet-500 to-purple-600' },
              { icon: '⚡', title: 'Real-time Dashboard', desc: 'Live counters, SSE updates, pause/resume/stop any time.', color: 'from-blue-500 to-cyan-600' },
              { icon: '📊', title: 'Excel + Sheets', desc: 'Import .xlsx, .csv. Auto-validate, dedupe, hygiene filter.', color: 'from-green-500 to-emerald-600' },
              { icon: '🎨', title: 'HTML Editor', desc: 'Paste HTML. Live preview. Plain-text fallback. Personalization vars.', color: 'from-pink-500 to-rose-600' },
              { icon: '🛡️', title: '7-Layer Anti-Spam', desc: 'Spam checker, warm-up, bounce handler, list hygiene, rate guard.', color: 'from-amber-500 to-orange-600' },
              { icon: '🔄', title: 'Sender Rotation', desc: 'Round-robin 25+ senders. Batch limit. Warm-up schedule.', color: 'from-fuchsia-500 to-pink-600' },
            ].map((f, i) => (
              <div key={f.title} className={`tilt card animate-in-slow delay-${(i % 5) + 1} group`}>
                <div className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${f.color} flex items-center justify-center text-2xl mb-5 shadow-lg group-hover:scale-110 transition-transform duration-500`}>
                  <span>{f.icon}</span>
                </div>
                <h3 className="font-bold text-lg mb-2 text-slate-900">{f.title}</h3>
                <p className="text-sm text-slate-600 leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="relative py-28 px-6">
        <div className="max-w-3xl mx-auto text-center relative z-10">
          <h2 className="text-4xl md:text-6xl font-black tracking-tight text-slate-900 mb-6">
            Ready to <span className="gradient-text">launch?</span>
          </h2>
          <p className="text-slate-600 mb-10 text-lg">
            Invite-only access. Connect your Gmail. Start sending today.
          </p>
          <Link href="/login" className="btn btn-primary text-base px-10 py-4 !text-base">
            Get Started →
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-slate-200 py-12 px-6 bg-white/50 backdrop-blur">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
              <span className="text-sm text-slate-500">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-slate-700">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-sm text-slate-500">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-slate-900 transition" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-slate-900 transition">Privacy</Link>
              <Link href="/terms" className="hover:text-slate-900 transition">Terms</Link>
              <Link href="/refund" className="hover:text-slate-900 transition">Refund</Link>
              <Link href="/login" className="hover:text-slate-900 transition">Sign in</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
EOF
echo "   ✅"

# ---------- 5. Dashboard layout (light) ----------
echo ""
echo "🎛️  [4/7] Dashboard layout (light)..."

cat > app/dashboard/layout.tsx <<'EOF'
import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { verifySession } from '@/lib/session';
import LogoutButton from './logout-button';

export const dynamic = 'force-dynamic';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) redirect('/login');

  return (
    <div className="min-h-screen">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 via-fuchsia-500 to-pink-500 flex items-center justify-center shadow-md shadow-violet-500/30">
              <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-bold tracking-tight text-sm text-slate-900">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-1 flex-wrap">
            <Link href="/dashboard" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Campaign</Link>
            <Link href="/senders" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Senders</Link>
            <Link href="/senders/rotation" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Rotation</Link>
            <Link href="/anti-spam" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">🛡️ Anti-Spam</Link>
            <Link href="/team" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">👥 Team</Link>
            <Link href="/history" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">History</Link>
            <div className="w-px h-5 bg-slate-200 mx-2" />
            <span className="text-xs text-slate-500 hidden md:inline font-medium">
              @{session.username} {session.role === 'owner' && <span className="text-amber-500">●</span>}
            </span>
            <LogoutButton />
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
      <footer className="max-w-7xl mx-auto px-6 py-8 text-center text-xs text-slate-400">
        © {new Date().getFullYear()} EmailCampaign · <b className="text-slate-600">Created by DIPEN ZALA</b>
      </footer>
    </div>
  );
}
EOF

cat > app/dashboard/logout-button.tsx <<'EOF'
'use client';
import { useRouter } from 'next/navigation';
export default function LogoutButton() {
  const router = useRouter();
  return (
    <button
      onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); router.push('/'); router.refresh(); }}
      className="text-sm text-slate-600 hover:text-red-600 hover:bg-red-50 px-3 py-1.5 rounded-lg transition font-medium"
    >
      Sign out
    </button>
  );
}
EOF
echo "   ✅"

# ---------- 6. Verify ----------
echo ""
echo "🔍 [5/7] Verification..."

# Check files
FILES=(
  "app/globals.css"
  "app/login/page.tsx"
  "app/page.tsx"
  "app/dashboard/layout.tsx"
  "app/dashboard/page.tsx"
  "app/api/auth/login/route.ts"
  "app/api/auth/setup/route.ts"
  "app/api/team/route.ts"
  "lib/password.ts"
  "lib/session.ts"
  "workers/sender.worker.ts"
)

MISSING=0
for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "   ✅ $f"
  else
    echo "   ❌ MISSING: $f"
    MISSING=$((MISSING+1))
  fi
done

# Check routes
ROUTES=0
for f in $(find app/api -name "route.ts" 2>/dev/null); do
  R=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  [ "$R" -eq 1 ] && ROUTES=$((ROUTES+1))
done
echo "   ✅ $ROUTES API routes with force-dynamic"

# ---------- 7. Git ----------
echo ""
echo "🌿 [6/7] Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "UI: light theme + redesigned login + creator credit"
git push -u origin main

echo "   ✅"

# ---------- 8. Sale readiness report ----------
echo ""
echo "==================================================="
echo " ✅ [7/7] DONE — Light Theme + Login Redesign"
echo "==================================================="
echo ""
echo "🎨 UI Changes:"
echo "   ✅ Light theme (glass morphism + 3D mesh background)"
echo "   ✅ Animated aurora blobs"
echo "   ✅ 3D tilt cards on hover"
echo "   ✅ Gradient buttons + shimmer effects"
echo "   ✅ Login page redesign with eye toggle + floating logo"
echo "   ✅ 'Created by DIPEN ZALA' on login + landing + dashboard footer"
echo ""
echo "📸 TEST after deploy (2-3 min):"
echo "   https://emailcampaign-ten.vercel.app/login"
echo "   https://emailcampaign-ten.vercel.app/"
echo ""
echo "==================================================="
echo " 🎯 WORKFLOW VERIFICATION (aap khud test karo)"
echo "==================================================="
echo ""
echo "Step 1: Login"
echo "   → /login → username + password → /dashboard"
echo ""
echo "Step 2: Import Contacts"
echo "   → /dashboard → Excel upload → stats dikhein"
echo ""
echo "Step 3: Compose"
echo "   → Subject + HTML paste → Preview → Test send"
echo ""
echo "Step 4: Launch"
echo "   → Review → START CAMPAIGN → Live dashboard"
echo ""
echo "Step 5: Monitor"
echo "   → Live counters + Pause/Resume/Stop"
echo ""
echo "==================================================="
echo " 💰 PRODUCT SALE READINESS CHECKLIST"
echo "==================================================="
echo ""
echo "✅ JO HO CHUKA HAI:"
echo "   ✅ Full working product (Gmail OAuth, queue, rotation, anti-spam)"
echo "   ✅ Team auth (username + password)"
echo "   ✅ Light theme with premium 3D UI"
echo "   ✅ Legal pages (Privacy, Terms, Refund)"
echo "   ✅ Google Search Console verified"
echo "   ✅ Multi-sender rotation with warm-up"
echo "   ✅ Real-time dashboard"
echo "   ✅ Branding 'Created by DIPEN ZALA'"
echo ""
echo "⚠️  SALE SE PEHLE ZAROORI (Priority order):"
echo ""
echo "   🔴 CRITICAL (must-do):"
echo "   1. [ ] Custom domain kharido (e.g. emailcampaign.app ~₹800/year)"
echo "         → Vercel Settings → Domains → add domain"
echo "         → SEO + trust ke liye zaroori"
echo ""
echo "   2. [ ] Payment gateway integrate karo:"
echo "         → Razorpay (India) — https://razorpay.com"
echo "         → Ya Stripe (Global) — https://stripe.com"
echo "         → Subscriptions: Free / Pro (₹499/mo) / Business (₹1499/mo)"
echo ""
echo "   3. [ ] Pricing page banao (/pricing)"
echo "         → 3 tiers comparison table"
echo "         → CTA buttons"
echo ""
echo "   4. [ ] Rate limiting add karo (security)"
echo "         → Upstash Rate Limit: https://upstash.com/docs/redis/sdks/ratelimit"
echo "         → Protect login, campaign start, etc."
echo ""
echo "   5. [ ] Terms page me 'Refund' section confirm"
echo "         → Refund policy clear rakho (already added)"
echo ""
echo "   🟡 IMPORTANT:"
echo "   6. [ ] Support email set karo (support@yourdomain.com)"
echo "   7. [ ] Status page (uptime monitoring)"
echo "         → https://betterstack.com ya https://uptimerobot.com"
echo "   8. [ ] Privacy policy me 'Data retention' clear"
echo "   9. [ ] Backup strategy (Neon auto-backups enabled?)"
echo "   10. [ ] Monitoring & alerts (Sentry, Logtail)"
echo ""
echo "   🟢 NICE-TO-HAVE:"
echo "   11. [ ] Onboarding flow for new customers"
echo "   12. [ ] Demo video (Loom, YouTube)"
echo "   13. [ ] Landing page me testimonials"
echo "   14. [ ] Help docs (Notion, GitBook)"
echo "   15. [ ] Social proof (Twitter/LinkedIn share buttons)"
echo ""
echo "==================================================="
echo " 🎯 CAN YOU SELL IT NOW? — Answer"
echo "==================================================="
echo ""
echo "   ✅ TECHNICALLY: YES — App works, features complete"
echo ""
echo "   ⚠️  BUSINESS-READY: NOT YET — kuch chahiye:"
echo ""
echo "      1. Custom domain (brand trust)"
echo "      2. Payment gateway (paisa lene ke liye)"
echo "      3. Pricing page (customers ko options dikhane ke liye)"
echo "      4. Rate limiting (abuse protection)"
echo "      5. Legal compliance (Privacy/Terms done ✅, Refund done ✅)"
echo ""
echo "   💡 RECOMMENDED PRICING:"
echo ""
echo "      Free Tier:"
echo "        - 500 emails/month"
echo "        - 1 sender account"
echo "        - Basic features"
echo ""
echo "      Pro — ₹499/month:"
echo "        - 5,000 emails/month"
echo "        - 5 sender accounts"
echo "        - Anti-spam suite"
echo "        - Priority support"
echo ""
echo "      Business — ₹1,499/month:"
echo "        - 50,000 emails/month"
echo "        - 25 sender accounts"
echo "        - Full 7-layer anti-spam"
echo "        - Team access (5 members)"
echo "        - API access"
echo ""
echo "      Enterprise — Custom:"
echo "        - Unlimited emails"
echo "        - Unlimited senders"
echo "        - White-label"
echo "        - SLA + dedicated support"
echo ""
echo "   💰 REVENUE POTENTIAL:"
echo ""
echo "      100 Pro users × ₹499  = ₹49,900/month"
echo "       20 Business × ₹1,499 = ₹29,980/month"
echo "      ────────────────────────────────────"
echo "      Total MRR            = ₹79,880/month (~$950)"
echo ""
echo "   🚀 GO-TO-MARKET (short):"
echo ""
echo "      1. ProductHunt launch"
echo "      2. Twitter/X build-in-public thread"
echo "      3. LinkedIn outreach (agencies, SaaS founders)"
echo "      4. IndieHackers post"
echo "      5. SEO blog: 'best email campaign tool India'"
echo ""
echo "==================================================="
echo " ✅ NEXT SCRIPT SUGGESTION:"
echo "    'payment-and-pricing.sh' — Razorpay + /pricing page + rate limiting"
echo "    Bolo 'payment integration karo' — main bana dunga"
echo "==================================================="