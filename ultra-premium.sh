#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎨 ULTRA PREMIUM REDESIGN — Cosmic Edition"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 1. Cosmic CSS System ----------
echo ""
echo "🎨 [1/9] Writing cosmic globals.css..."

cat > app/globals.css <<'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ============================================================
   COSMIC EDITION — Deep Obsidian + Electric Blue
   ============================================================ */

:root {
  --bg: #06070d;
  --bg-elev: #0c0e18;
  --surface: rgba(255, 255, 255, 0.025);
  --surface-hover: rgba(255, 255, 255, 0.05);
  --border: rgba(255, 255, 255, 0.07);
  --border-strong: rgba(255, 255, 255, 0.12);

  --fg: #f4f5fa;
  --fg-soft: #a8adbd;
  --fg-muted: #6e7385;
  --fg-dim: #4a4d5c;

  --accent: #4f9cff;
  --accent-bright: #6db1ff;
  --accent-deep: #2c72d9;
  --emerald: #30d158;
  --amber: #ff9f0a;
  --red: #ff453a;
  --violet: #7c5cff;

  --ease-apple: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}

* { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }

html {
  scroll-behavior: smooth;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  scroll-padding-top: 80px;
}

body {
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Segoe UI", sans-serif;
  font-feature-settings: "cv02", "cv03", "cv04", "cv11", "ss01";
  overflow-x: hidden;
  letter-spacing: -0.011em;
  line-height: 1.5;
  min-height: 100vh;
}

/* ---------- Deep space background ---------- */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -3;
  background:
    radial-gradient(ellipse 80% 60% at 50% -10%, rgba(79, 156, 255, 0.15) 0%, transparent 60%),
    radial-gradient(ellipse 60% 50% at 100% 30%, rgba(124, 92, 255, 0.08) 0%, transparent 55%),
    radial-gradient(ellipse 70% 50% at 0% 80%, rgba(48, 209, 88, 0.06) 0%, transparent 55%),
    radial-gradient(ellipse 50% 40% at 50% 100%, rgba(79, 156, 255, 0.05) 0%, transparent 60%),
    linear-gradient(180deg, #06070d 0%, #080a12 100%);
  pointer-events: none;
}

/* Star field */
body::after {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -2;
  background-image:
    radial-gradient(1px 1px at 20% 30%, rgba(255, 255, 255, 0.4), transparent),
    radial-gradient(1px 1px at 60% 70%, rgba(255, 255, 255, 0.25), transparent),
    radial-gradient(1px 1px at 80% 20%, rgba(255, 255, 255, 0.35), transparent),
    radial-gradient(1px 1px at 30% 80%, rgba(255, 255, 255, 0.2), transparent),
    radial-gradient(1.5px 1.5px at 45% 40%, rgba(79, 156, 255, 0.6), transparent),
    radial-gradient(1.5px 1.5px at 75% 55%, rgba(124, 92, 255, 0.5), transparent),
    radial-gradient(1px 1px at 90% 90%, rgba(255, 255, 255, 0.3), transparent);
  background-size: 800px 800px, 900px 900px, 700px 700px, 1000px 1000px, 1200px 1200px, 1100px 1100px, 950px 950px;
  background-position: 0 0, 100px 200px, 300px 100px, 500px 400px, 200px 600px, 700px 300px, 400px 800px;
  opacity: 0.7;
  animation: starDrift 200s linear infinite;
}

@keyframes starDrift {
  from { background-position: 0 0, 100px 200px, 300px 100px, 500px 400px, 200px 600px, 700px 300px, 400px 800px; }
  to { background-position: -800px -800px, -800px -700px, -400px -600px, -500px -400px, -1000px -600px, -400px -800px, -550px -200px; }
}

/* ============================================================
   TYPOGRAPHY
   ============================================================ */

h1, h2, h3, h4, h5, h6 {
  letter-spacing: -0.025em;
  font-weight: 600;
  line-height: 1.15;
}

.headline {
  font-size: clamp(2.75rem, 7vw, 6rem);
  font-weight: 700;
  line-height: 1.02;
  letter-spacing: -0.035em;
  background: linear-gradient(180deg, #ffffff 0%, #a8adbd 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.headline-sm {
  font-size: clamp(2rem, 4vw, 3.25rem);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.03em;
  background: linear-gradient(180deg, #ffffff 0%, #b8bccb 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--accent-bright);
  margin-bottom: 1rem;
}

.subhead {
  font-size: clamp(1rem, 1.4vw, 1.25rem);
  line-height: 1.6;
  color: var(--fg-soft);
  font-weight: 400;
  max-width: 640px;
}

/* ============================================================
   GLASS CARDS — 3D depth
   ============================================================ */

.card {
  position: relative;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 1.25rem;
  padding: 1.5rem;
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  box-shadow:
    0 1px 0 0 rgba(255, 255, 255, 0.05) inset,
    0 0 0 1px rgba(255, 255, 255, 0.02),
    0 20px 50px -20px rgba(0, 0, 0, 0.7);
  transition: all 0.5s var(--ease-apple);
}

.card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.12) 0%,
    rgba(255, 255, 255, 0.02) 50%,
    rgba(79, 156, 255, 0.15) 100%
  );
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}

.card-hover:hover {
  background: var(--surface-hover);
  transform: translateY(-4px);
  box-shadow:
    0 1px 0 0 rgba(255, 255, 255, 0.08) inset,
    0 0 0 1px rgba(79, 156, 255, 0.15),
    0 40px 80px -20px rgba(79, 156, 255, 0.15),
    0 30px 60px -20px rgba(0, 0, 0, 0.8);
}

/* ============================================================
   BUTTONS — Premium
   ============================================================ */

.btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.7rem 1.5rem;
  font-size: 0.9375rem;
  font-weight: 500;
  letter-spacing: -0.005em;
  border-radius: 0.75rem;
  border: none;
  cursor: pointer;
  user-select: none;
  transition: all 0.35s var(--ease-apple);
  overflow: hidden;
  font-family: inherit;
}

.btn-primary {
  color: white;
  background: linear-gradient(135deg, #4f9cff 0%, #2c72d9 100%);
  box-shadow:
    0 1px 0 0 rgba(255, 255, 255, 0.2) inset,
    0 8px 24px -6px rgba(79, 156, 255, 0.5),
    0 0 0 1px rgba(79, 156, 255, 0.3);
}

.btn-primary::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, transparent 0%, rgba(255, 255, 255, 0.2) 50%, transparent 100%);
  transform: translateX(-100%);
  transition: transform 0.6s var(--ease-apple);
}

.btn-primary:hover:not(:disabled)::after {
  transform: translateX(100%);
}

.btn-primary:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow:
    0 1px 0 0 rgba(255, 255, 255, 0.25) inset,
    0 16px 40px -8px rgba(79, 156, 255, 0.65),
    0 0 0 1px rgba(79, 156, 255, 0.5);
}

.btn-primary:active:not(:disabled) {
  transform: translateY(0) scale(0.98);
  transition-duration: 0.1s;
}

.btn-primary:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.btn-ghost {
  color: var(--fg);
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
}

.btn-ghost:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.15);
  transform: translateY(-2px);
}

.btn-danger {
  color: white;
  background: linear-gradient(135deg, #ff453a 0%, #d92c25 100%);
  box-shadow: 0 8px 24px -6px rgba(255, 69, 58, 0.4);
}

.btn-danger:hover {
  transform: translateY(-2px);
}

.btn-lg {
  padding: 1rem 2rem;
  font-size: 1rem;
  border-radius: 1rem;
}

/* ============================================================
   INPUTS
   ============================================================ */

.input {
  width: 100%;
  padding: 0.75rem 1rem;
  font-size: 0.9375rem;
  color: var(--fg);
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  border-radius: 0.625rem;
  transition: all 0.3s var(--ease-apple);
  font-family: inherit;
  outline: none;
}

.input::placeholder { color: var(--fg-dim); }

.input:hover {
  border-color: rgba(255, 255, 255, 0.15);
  background: rgba(255, 255, 255, 0.05);
}

.input:focus {
  border-color: var(--accent);
  background: rgba(255, 255, 255, 0.06);
  box-shadow: 0 0 0 4px rgba(79, 156, 255, 0.15);
}

/* ============================================================
   NAV
   ============================================================ */

.glass-nav {
  background: rgba(6, 7, 13, 0.72);
  backdrop-filter: saturate(180%) blur(24px);
  -webkit-backdrop-filter: saturate(180%) blur(24px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  box-shadow: 0 1px 0 0 rgba(255, 255, 255, 0.02) inset;
}

/* ============================================================
   GRADIENT TEXT
   ============================================================ */

.gradient-text {
  background: linear-gradient(135deg, #4f9cff 0%, #6db1ff 50%, #7c5cff 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.gradient-text-emerald {
  background: linear-gradient(135deg, #4f9cff 0%, #30d158 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

/* ============================================================
   3D TILT
   ============================================================ */

.tilt {
  transition: transform 0.6s var(--ease-apple), box-shadow 0.6s var(--ease-apple);
  transform-style: preserve-3d;
  will-change: transform;
}

.tilt:hover {
  transform: perspective(1600px) rotateX(2deg) rotateY(-2deg) translateY(-6px) scale(1.01);
}

/* ============================================================
   FLOATING
   ============================================================ */

@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}

.float { animation: float 6s var(--ease-apple) infinite; }
.float-slow { animation: float 9s var(--ease-apple) infinite; }

/* ============================================================
   GLOW
   ============================================================ */

.glow-blue {
  box-shadow: 0 0 0 1px rgba(79, 156, 255, 0.2), 0 0 60px rgba(79, 156, 255, 0.3);
}

@keyframes pulse-glow {
  0%, 100% { opacity: 1; box-shadow: 0 0 20px rgba(79, 156, 255, 0.3); }
  50% { opacity: 0.8; box-shadow: 0 0 40px rgba(79, 156, 255, 0.55); }
}

.glow-pulse { animation: pulse-glow 3s ease-in-out infinite; }

/* ============================================================
   BADGE
   ============================================================ */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.85rem;
  font-size: 0.75rem;
  font-weight: 500;
  letter-spacing: -0.005em;
  border-radius: 999px;
  color: var(--fg-soft);
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(12px);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--emerald);
  box-shadow: 0 0 10px rgba(48, 209, 88, 0.8);
  animation: pulse 2.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(1.2); }
}

/* ============================================================
   FADE-IN
   ============================================================ */

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(0); }
}

.fade-up { animation: fadeUp 0.9s var(--ease-out) both; }
.fade-up-d1 { animation-delay: 0.1s; }
.fade-up-d2 { animation-delay: 0.2s; }
.fade-up-d3 { animation-delay: 0.3s; }
.fade-up-d4 { animation-delay: 0.4s; }
.fade-up-d5 { animation-delay: 0.5s; }

/* ============================================================
   REVEAL (scroll-triggered)
   ============================================================ */

[data-reveal] {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 1s var(--ease-out), transform 1s var(--ease-out);
  will-change: opacity, transform;
}

[data-reveal="fade"] { transform: none; }
[data-reveal="scale"] { transform: scale(0.94); }
[data-reveal="blur"] { filter: blur(14px); transform: translateY(30px); }
[data-reveal].is-visible { opacity: 1; transform: none; filter: none; }

[data-reveal-delay="1"] { transition-delay: 0.1s; }
[data-reveal-delay="2"] { transition-delay: 0.2s; }
[data-reveal-delay="3"] { transition-delay: 0.3s; }
[data-reveal-delay="4"] { transition-delay: 0.4s; }
[data-reveal-delay="5"] { transition-delay: 0.5s; }
[data-reveal-delay="6"] { transition-delay: 0.6s; }

/* ============================================================
   SECTION
   ============================================================ */

.section { position: relative; padding: 7rem 1.5rem; overflow: hidden; }
.container { max-width: 1200px; margin: 0 auto; padding: 0 1.5rem; }

/* ============================================================
   DIVIDER
   ============================================================ */

.divider {
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.08), transparent);
}

/* ============================================================
   SCROLLBAR
   ============================================================ */

::-webkit-scrollbar { width: 12px; height: 12px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  border: 3px solid transparent;
  background-clip: padding-box;
}
::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.2);
  background-clip: padding-box;
}

/* ============================================================
   SPINNER
   ============================================================ */

@keyframes spin { to { transform: rotate(360deg); } }
.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.2);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

/* ============================================================
   UTILITY OVERRIDES
   ============================================================ */

.text-slate-100, .text-white { color: var(--fg) !important; }
.text-slate-200 { color: var(--fg) !important; }
.text-slate-300 { color: var(--fg-soft) !important; }
.text-slate-400 { color: var(--fg-muted) !important; }
.text-slate-500 { color: var(--fg-dim) !important; }
.text-slate-900 { color: var(--fg) !important; }
.text-black { color: var(--fg) !important; }

.bg-slate-950, .bg-slate-900, .bg-slate-100 { background: transparent !important; }
.bg-slate-800 { background: rgba(255, 255, 255, 0.04) !important; }
.bg-white { background: var(--surface) !important; }
.bg-white\/5, .bg-white\/10, .bg-black\/5 { background: rgba(255, 255, 255, 0.03) !important; }

.border-slate-800, .border-slate-700, .border-black\/10 { border-color: var(--border) !important; }
.border-white\/5, .border-white\/10 { border-color: var(--border) !important; }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
CSSEOF
echo "   ✅"

# ---------- 2. Nav component (cosmic) ----------
echo ""
echo "🧭 [2/9] Cosmic nav component..."

mkdir -p components
cat > components/nav.tsx <<'EOF'
'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';

type NavProps = { username?: string; role?: string };

const LINKS = [
  { href: '/dashboard', label: 'Campaign', icon: '◆' },
  { href: '/senders', label: 'Senders', icon: '◈' },
  { href: '/senders/rotation', label: 'Rotation', icon: '⟳' },
  { href: '/anti-spam', label: 'Anti-Spam', icon: '◉' },
  { href: '/team', label: 'Team', icon: '◐' },
  { href: '/account/sessions', label: 'Sessions', icon: '⌘' },
  { href: '/history', label: 'History', icon: '▤' },
];

export default function Nav({ username, role }: NavProps) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const logout = async () => {
    setBusy(true);
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/');
    router.refresh();
  };

  const isActive = (href: string) =>
    href === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(href);

  return (
    <nav className="glass-nav sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 md:px-6 py-3 flex items-center justify-between gap-3">

        {/* LEFT: Back + Logo */}
        <div className="flex items-center gap-2 min-w-0">
          <button
            onClick={() => router.back()}
            className="flex items-center justify-center w-9 h-9 rounded-full bg-white/[0.04] hover:bg-white/[0.08] border border-white/[0.06] hover:border-white/[0.12] transition-all duration-300 text-[var(--fg-soft)] hover:text-white group"
            title="Go back"
            aria-label="Go back"
          >
            <svg className="w-4 h-4 group-hover:-translate-x-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </button>

          <Link href="/dashboard" className="flex items-center gap-2.5 hover:opacity-80 transition-opacity min-w-0 group">
            <div className="relative w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff] to-[#7c5cff] opacity-90 group-hover:opacity-100 transition-opacity" />
              <div className="absolute inset-0 bg-gradient-to-br from-white/30 to-transparent" />
              <svg className="relative w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-semibold tracking-tight text-sm text-white truncate">EmailCampaign</span>
          </Link>
        </div>

        {/* CENTER: Links */}
        <div className="hidden lg:flex items-center gap-0.5">
          {LINKS.map(l => (
            <Link
              key={l.href}
              href={l.href}
              className={`relative text-xs font-medium px-3 py-2 rounded-lg transition-all duration-300 ${
                isActive(l.href)
                  ? 'text-white bg-white/[0.06]'
                  : 'text-[var(--fg-soft)] hover:text-white hover:bg-white/[0.04]'
              }`}
            >
              <span className="mr-1.5 opacity-60 text-[10px]">{l.icon}</span>
              {l.label}
              {isActive(l.href) && (
                <span className="absolute -bottom-px left-3 right-3 h-px bg-gradient-to-r from-transparent via-[var(--accent)] to-transparent" />
              )}
            </Link>
          ))}
        </div>

        {/* RIGHT: User + actions */}
        <div className="flex items-center gap-2">
          <div className="hidden md:flex items-center gap-2 pl-3 border-l border-white/[0.08]">
            <div className="relative">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#4f9cff] to-[#7c5cff] flex items-center justify-center text-white text-xs font-bold">
                {(username || 'U')[0].toUpperCase()}
              </div>
              {role === 'owner' && (
                <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-[var(--emerald)] border-2 border-[#06070d]" />
              )}
            </div>
            <div className="flex flex-col leading-tight">
              <span className="text-xs font-medium text-white">@{username || 'user'}</span>
              <span className="text-[10px] text-[var(--fg-dim)]">{role === 'owner' ? 'Owner' : 'Member'}</span>
            </div>
          </div>

          <button
            onClick={logout}
            disabled={busy}
            className="hidden md:inline-flex text-xs font-medium text-[var(--fg-soft)] hover:text-[var(--red)] px-3 py-2 rounded-lg hover:bg-[var(--red)]/[0.08] transition-all duration-300 disabled:opacity-50"
          >
            {busy ? 'Signing out…' : 'Sign out'}
          </button>

          <button
            onClick={() => setOpen(!open)}
            className="lg:hidden w-9 h-9 rounded-lg bg-white/[0.04] hover:bg-white/[0.08] border border-white/[0.06] flex items-center justify-center transition-colors text-white"
            aria-label="Toggle menu"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              {open ? (
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              ) : (
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>
      </div>

      {/* Mobile dropdown */}
      {open && (
        <div className="lg:hidden border-t border-white/[0.06] bg-[#06070d]/95 backdrop-blur-xl">
          <div className="px-4 py-3 space-y-1">
            {LINKS.map(l => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className={`flex items-center gap-3 text-sm font-medium px-3 py-2.5 rounded-lg transition-colors ${
                  isActive(l.href)
                    ? 'text-white bg-[var(--accent)]/[0.12] border border-[var(--accent)]/30'
                    : 'text-[var(--fg-soft)] hover:bg-white/[0.04]'
                }`}
              >
                <span className="opacity-60 text-xs">{l.icon}</span>
                {l.label}
              </Link>
            ))}
            <div className="pt-2 mt-2 border-t border-white/[0.06]">
              <div className="flex items-center gap-2.5 px-3 py-2">
                <div className="w-7 h-7 rounded-full bg-gradient-to-br from-[#4f9cff] to-[#7c5cff] flex items-center justify-center text-white text-[10px] font-bold">
                  {(username || 'U')[0].toUpperCase()}
                </div>
                <div className="flex flex-col leading-tight">
                  <span className="text-xs text-white">@{username || 'user'}</span>
                  <span className="text-[10px] text-[var(--fg-dim)]">{role === 'owner' ? 'Owner' : 'Member'}</span>
                </div>
              </div>
              <button
                onClick={logout}
                disabled={busy}
                className="w-full text-left text-sm font-medium px-3 py-2.5 rounded-lg text-[var(--red)] hover:bg-[var(--red)]/[0.08] transition-colors"
              >
                {busy ? 'Signing out…' : 'Sign out'}
              </button>
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}
EOF
sed -i 's/\r$//' components/nav.tsx
echo "   ✅"

# ---------- 3. Help contact (cosmic) ----------
echo ""
echo "📞 [3/9] Help contact widget..."

cat > components/help-contact.tsx <<'EOF'
'use client';
import { useState } from 'react';

const PHONE = '8128931029';
const NAME = 'DIPEN ZALA';

export default function HelpContact() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-6 right-6 z-50 w-14 h-14 rounded-full flex items-center justify-center transition-all duration-500 hover:scale-110 active:scale-95 group"
        style={{
          background: 'linear-gradient(135deg, #4f9cff 0%, #7c5cff 100%)',
          boxShadow: '0 8px 32px rgba(79, 156, 255, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.15) inset',
        }}
        aria-label="Help & Contact"
      >
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-white/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
        {open ? (
          <svg className="relative w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <svg className="relative w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        )}
      </button>

      {open && (
        <div
          className="fixed bottom-24 right-6 z-50 w-[340px] rounded-2xl overflow-hidden"
          style={{
            background: 'rgba(12, 14, 24, 0.92)',
            backdropFilter: 'blur(24px) saturate(180%)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            boxShadow: '0 40px 80px -20px rgba(0, 0, 0, 0.9), 0 0 0 1px rgba(79, 156, 255, 0.15)',
            animation: 'fadeUp 0.4s cubic-bezier(0.16, 1, 0.3, 1) both',
          }}
        >
          <div className="relative px-5 py-4 overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff]/20 to-[#7c5cff]/10" />
            <div className="relative flex items-center gap-3">
              <div className="w-11 h-11 rounded-full bg-gradient-to-br from-[#4f9cff] to-[#7c5cff] flex items-center justify-center text-white text-sm font-bold shadow-lg">
                {NAME.split(' ').map(n => n[0]).join('')}
              </div>
              <div>
                <div className="text-white font-semibold text-sm">{NAME}</div>
                <div className="text-[var(--fg-soft)] text-xs flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[var(--emerald)] animate-pulse" />
                  Online · Usually replies instantly
                </div>
              </div>
            </div>
          </div>

          <div className="p-5 space-y-2.5">
            <p className="text-xs text-[var(--fg-muted)] leading-relaxed pb-2">
              Koi bhi help, query, ya issue ke liye direct contact karein:
            </p>

            <a
              href={`tel:+91${PHONE}`}
              className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.03] hover:bg-white/[0.06] border border-white/[0.05] hover:border-[var(--emerald)]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[var(--emerald)]/15 flex items-center justify-center text-[var(--emerald)] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[var(--fg-dim)]">Call</div>
                <div className="text-sm font-semibold text-white">+91 {PHONE}</div>
              </div>
              <svg className="w-4 h-4 text-[var(--fg-dim)] group-hover:text-[var(--emerald)] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>

            <a
              href={`https://wa.me/91${PHONE}?text=${encodeURIComponent('Hi, mujhe EmailCampaign ke baare me help chahiye.')}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.03] hover:bg-white/[0.06] border border-white/[0.05] hover:border-[#25D366]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[#25D366]/15 flex items-center justify-center text-[#25D366] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[var(--fg-dim)]">WhatsApp</div>
                <div className="text-sm font-semibold text-white">Chat now</div>
              </div>
              <svg className="w-4 h-4 text-[var(--fg-dim)] group-hover:text-[#25D366] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>

            <div className="pt-3 border-t border-white/[0.06] text-center">
              <div className="text-[10px] text-[var(--fg-dim)]">
                Powered by <b className="text-[var(--accent)]">{NAME}</b>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
EOF
sed -i 's/\r$//' components/help-contact.tsx
echo "   ✅"

# ---------- 4. Reveal component ----------
echo ""
echo "🎬 [4/9] Reveal + Parallax..."

cat > components/reveal.tsx <<'EOF'
'use client';
import { useEffect, useRef, ReactNode } from 'react';

export function Reveal({
  children, type = 'up', delay = 0, className = '', as: Tag = 'div',
}: {
  children: ReactNode;
  type?: 'up' | 'fade' | 'left' | 'right' | 'scale' | 'blur';
  delay?: 0 | 1 | 2 | 3 | 4 | 5 | 6;
  className?: string;
  as?: any;
}) {
  const ref = useRef<HTMLElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add('is-visible');
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: '0px 0px -60px 0px' }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return (
    <Tag ref={ref} data-reveal={type} data-reveal-delay={delay || undefined} className={className}>
      {children}
    </Tag>
  );
}
EOF
sed -i 's/\r$//' components/reveal.tsx
echo "   ✅"

# ---------- 5. Landing page (cosmic premium) ----------
echo ""
echo "✨ [5/9] Cosmic landing page..."

cat > app/page.tsx <<'EOF'
import Link from 'next/link';
import { Reveal } from '@/components/reveal';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      {/* NAV */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="relative w-9 h-9 rounded-xl overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff] to-[#7c5cff]" />
              <div className="absolute inset-0 bg-gradient-to-br from-white/30 to-transparent" />
              <svg className="relative w-full h-full p-2 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="text-sm font-semibold tracking-tight text-white">EmailCampaign</span>
          </Link>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-[var(--fg-soft)]">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#workflow" className="hover:text-white transition-colors">Workflow</a>
            <a href="#security" className="hover:text-white transition-colors">Security</a>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-[var(--fg-soft)] hover:text-white transition-colors hidden sm:block">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-xs !px-4 !py-2">Get Started</Link>
          </div>
        </div>
      </nav>

      {/* HERO */}
      <section className="relative pt-36 pb-24 px-6 md:pt-48 md:pb-32">
        <div className="container relative z-10 text-center">
          <Reveal type="fade">
            <div className="badge mb-8 fade-up">
              <span className="badge-dot" />
              Powered by Gmail API · OAuth 2.0
            </div>
          </Reveal>

          <Reveal type="up" delay={1}>
            <h1 className="headline max-w-5xl mx-auto">
              Send email<br />
              <span className="gradient-text">that lands.</span>
            </h1>
          </Reveal>

          <Reveal type="up" delay={2}>
            <p className="subhead mx-auto text-center mt-8">
              Production-grade email campaigns with intelligent sender rotation, seven-layer anti-spam, and real-time analytics. Built for teams that care about deliverability.
            </p>
          </Reveal>

          <Reveal type="up" delay={3}>
            <div className="mt-12 flex flex-wrap items-center justify-center gap-4">
              <Link href="/login" className="btn btn-primary btn-lg">
                Start Free Trial
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </Link>
              <a href="#features" className="btn btn-ghost btn-lg">
                Explore Features
              </a>
            </div>
          </Reveal>

          <Reveal type="up" delay={4}>
            <div className="mt-16 flex flex-wrap items-center justify-center gap-8 text-xs text-[var(--fg-muted)]">
              {['No credit card', 'OAuth 2.0 secure', 'Cancel anytime'].map((t) => (
                <span key={t} className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-[var(--emerald)]" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  {t}
                </span>
              ))}
            </div>
          </Reveal>
        </div>

        {/* Dashboard preview */}
        <div className="container relative mt-24">
          <Reveal type="blur" delay={5}>
            <div className="tilt card !p-0 overflow-hidden !rounded-2xl">
              <div className="flex items-center gap-2 px-5 py-3.5 border-b border-white/[0.06]">
                <span className="w-3 h-3 rounded-full bg-[#ff5f57]" />
                <span className="w-3 h-3 rounded-full bg-[#febc2e]" />
                <span className="w-3 h-3 rounded-full bg-[#28c840]" />
                <span className="ml-3 text-xs text-[var(--fg-dim)] font-mono">campaign · live</span>
                <span className="ml-auto flex items-center gap-1.5 text-xs text-[var(--emerald)]">
                  <span className="w-1.5 h-1.5 rounded-full bg-[var(--emerald)] animate-pulse" />
                  Running
                </span>
              </div>
              <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
                {[
                  { l: 'SENT', v: '12,847', c: 'var(--accent)' },
                  { l: 'DELIVERED', v: '12,412', c: 'var(--emerald)' },
                  { l: 'PENDING', v: '435', c: 'var(--amber)' },
                  { l: 'FAILED', v: '12', c: 'var(--red)' },
                ].map(s => (
                  <div key={s.l} className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-5">
                    <div className="text-[10px] tracking-[0.15em] text-[var(--fg-dim)] font-medium">{s.l}</div>
                    <div className="text-3xl font-semibold mt-2 tracking-tight" style={{ color: s.c }}>{s.v}</div>
                  </div>
                ))}
              </div>
              <div className="px-8 pb-8">
                <div className="h-1.5 w-full bg-white/[0.04] rounded-full overflow-hidden">
                  <div className="h-full w-[96%] bg-gradient-to-r from-[#4f9cff] via-[#6db1ff] to-[#30d158] rounded-full" />
                </div>
                <div className="flex justify-between text-xs text-[var(--fg-dim)] mt-3">
                  <span>Campaign progress</span>
                  <span className="text-white font-medium">96.4%</span>
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Features</div>
              <h2 className="headline-sm">
                Built with real infrastructure.
              </h2>
              <p className="subhead mx-auto mt-5">
                Every feature engineered for scale. No shortcuts, no fake numbers.
              </p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { title: 'OAuth 2.0 Only', desc: 'Your Gmail password never touches our servers. Tokens encrypted with AES-256-GCM at rest.', icon: 'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z' },
              { title: 'Real-time Dashboard', desc: 'Live counters via Server-Sent Events. Pause, resume, or stop any campaign instantly.', icon: 'M13 10V3L4 14h7v7l9-11h-7z' },
              { title: 'Smart Import', desc: 'Excel, CSV, Google Sheets. Auto-validate, dedupe, and filter disposables.', icon: 'M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2' },
              { title: 'HTML Email Editor', desc: 'Paste your HTML. Live desktop + mobile preview. Automatic plain-text fallback.', icon: 'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4' },
              { title: '7-Layer Anti-Spam', desc: 'Content checker, warm-up schedules, bounce handler, list hygiene, and rate guard.', icon: 'M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z' },
              { title: 'Sender Rotation', desc: 'Round-robin across 25+ Gmail accounts with per-sender batch limits and reputation.', icon: 'M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15' },
            ].map((f, i) => (
              <Reveal key={f.title} type="up" delay={((i % 3) + 1) as any}>
                <div className="tilt card card-hover h-full">
                  <div className="w-11 h-11 rounded-xl flex items-center justify-center mb-5" style={{
                    background: 'linear-gradient(135deg, rgba(79, 156, 255, 0.15) 0%, rgba(124, 92, 255, 0.1) 100%)',
                    border: '1px solid rgba(79, 156, 255, 0.2)',
                  }}>
                    <svg className="w-5 h-5 text-[var(--accent)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                      <path strokeLinecap="round" strokeLinejoin="round" d={f.icon} />
                    </svg>
                  </div>
                  <h3 className="text-base font-semibold text-white mb-2">{f.title}</h3>
                  <p className="text-sm text-[var(--fg-soft)] leading-relaxed">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* WORKFLOW */}
      <section id="workflow" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Workflow</div>
              <h2 className="headline-sm">Three steps. Zero friction.</h2>
              <p className="subhead mx-auto mt-5">From import to inbox in under two minutes.</p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { n: '01', title: 'Import', desc: 'Upload Excel, CSV, or connect Google Sheets. Validation happens automatically.' },
              { n: '02', title: 'Compose', desc: 'Paste HTML. Preview on desktop and mobile. Send a test in one click.' },
              { n: '03', title: 'Launch', desc: 'Hit start. Watch live counters. Pause, resume, or stop anytime.' },
            ].map((s, i) => (
              <Reveal key={s.n} type="up" delay={((i % 3) + 1) as any}>
                <div className="card card-hover h-full relative overflow-hidden">
                  <div className="absolute top-4 right-5 text-6xl font-black text-white/[0.03] tracking-tighter">{s.n}</div>
                  <div className="relative">
                    <div className="text-4xl font-semibold tracking-tighter gradient-text mb-4">{s.n}</div>
                    <h3 className="text-lg font-semibold text-white mb-2">{s.title}</h3>
                    <p className="text-sm text-[var(--fg-soft)] leading-relaxed">{s.desc}</p>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* SECURITY */}
      <section id="security" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="card !p-12 md:!p-16 !rounded-3xl overflow-hidden relative">
              <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff]/10 via-transparent to-[#7c5cff]/10" />
              <div className="absolute top-0 right-0 w-96 h-96 bg-[#4f9cff]/10 rounded-full blur-[120px]" />
              <div className="relative">
                <div className="eyebrow">Security</div>
                <h2 className="headline-sm !max-w-2xl">
                  Your data. Your senders. Your control.
                </h2>
                <p className="text-[var(--fg-soft)] text-lg leading-relaxed mt-6 max-w-lg">
                  Tokens encrypted with AES-256-GCM. Sessions signed with HMAC-SHA256. Login rate-limited. Every action audited.
                </p>
                <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-10">
                  {[
                    'AES-256-GCM encryption',
                    'HMAC-signed sessions',
                    'Login rate limiting',
                    'Device-bound sessions',
                    'OAuth 2.0 only',
                    'No password storage',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3">
                      <div className="w-5 h-5 rounded-md bg-[var(--emerald)]/20 flex items-center justify-center flex-shrink-0">
                        <svg className="w-3 h-3 text-[var(--emerald)]" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <span className="text-sm text-[var(--fg-soft)]">{f}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* CTA */}
      <section className="section text-center">
        <div className="container">
          <Reveal type="up">
            <h2 className="headline max-w-3xl mx-auto">
              Ready to <span className="gradient-text">launch?</span>
            </h2>
          </Reveal>
          <Reveal type="up" delay={1}>
            <p className="subhead mx-auto text-center mt-6 mb-10">
              Invite-only access. Connect your Gmail. Start sending today.
            </p>
          </Reveal>
          <Reveal type="up" delay={2}>
            <Link href="/login" className="btn btn-primary btn-lg">
              Get Started
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </Link>
          </Reveal>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="relative border-t border-white/[0.06] py-12">
        <div className="container">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#4f9cff] to-[#7c5cff]" />
              <span className="text-xs text-[var(--fg-muted)]">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-white">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-xs text-[var(--fg-muted)]">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-white transition-colors" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-white transition-colors">Privacy</Link>
              <Link href="/terms" className="hover:text-white transition-colors">Terms</Link>
              <Link href="/refund" className="hover:text-white transition-colors">Refund</Link>
              <Link href="/login" className="hover:text-white transition-colors">Sign in</Link>
            </div>
          </div>
          <div className="mt-6 pt-6 border-t border-white/[0.04] flex flex-wrap items-center justify-center md:justify-between gap-4 text-xs">
            <span className="text-[var(--fg-dim)]">Help & Support:</span>
            <div className="flex items-center gap-4">
              <a href="tel:+918128931029" className="text-[var(--accent)] hover:underline font-medium">📞 +91 8128931029</a>
              <a href="https://wa.me/918128931029" className="text-[#25D366] hover:underline font-medium" target="_blank" rel="noopener">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/page.tsx
echo "   ✅"

# ---------- 6. Layout wrapper for protected pages ----------
echo ""
echo "🛡️  [6/9] Protected layout (with nav everywhere)..."

# Delete old (protected) if exists
rm -rf "app/(protected)" 2>/dev/null || true

mkdir -p "app/(protected)"

cat > "app/(protected)/layout.tsx" <<'EOF'
import { requireAuth } from '@/lib/auth-guard';
import Nav from '@/components/nav';
import HelpContact from '@/components/help-contact';

export const dynamic = 'force-dynamic';

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const session = await requireAuth();

  return (
    <div className="min-h-screen">
      <Nav username={session.username} role={session.role} />

      <main className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-8">
        {children}
      </main>

      <footer className="max-w-7xl mx-auto px-4 md:px-6 py-8 mt-8 border-t border-white/[0.05]">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="text-[var(--fg-muted)]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-white">Created by DIPEN ZALA</b>
          </div>
          <div className="flex items-center gap-5">
            <span className="text-[var(--fg-dim)]">Help:</span>
            <a href="tel:+918128931029" className="text-[var(--accent)] hover:underline font-medium">📞 8128931029</a>
            <a href="https://wa.me/918128931029" target="_blank" rel="noopener" className="text-[#25D366] hover:underline font-medium">💬 WhatsApp</a>
          </div>
        </div>
      </footer>

      <HelpContact />
    </div>
  );
}
EOF
sed -i 's/\r$//' "app/(protected)/layout.tsx"

# Move existing pages into protected group
move_to_protected() {
  local name="$1"
  if [ -d "app/$name" ]; then
    rm -rf "app/(protected)/$name" 2>/dev/null || true
    mv "app/$name" "app/(protected)/$name"
    echo "   → app/$name → app/(protected)/$name"
  fi
}

move_to_protected "senders"
move_to_protected "anti-spam"
move_to_protected "team"
move_to_protected "history"
move_to_protected "account"

echo "   ✅ Pages wrapped with nav + help"

# ---------- 7. Dashboard layout (uses same nav) ----------
echo ""
echo "🎛️  [7/9] Dashboard layout update..."

cat > app/dashboard/layout.tsx <<'EOF'
import { requireAuth } from '@/lib/auth-guard';
import Nav from '@/components/nav';
import HelpContact from '@/components/help-contact';

export const dynamic = 'force-dynamic';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await requireAuth();

  return (
    <div className="min-h-screen">
      <Nav username={session.username} role={session.role} />

      <main className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-8">
        {children}
      </main>

      <footer className="max-w-7xl mx-auto px-4 md:px-6 py-8 mt-8 border-t border-white/[0.05]">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="text-[var(--fg-muted)]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-white">Created by DIPEN ZALA</b>
          </div>
          <div className="flex items-center gap-5">
            <span className="text-[var(--fg-dim)]">Help:</span>
            <a href="tel:+918128931029" className="text-[var(--accent)] hover:underline font-medium">📞 8128931029</a>
            <a href="https://wa.me/918128931029" target="_blank" rel="noopener" className="text-[#25D366] hover:underline font-medium">💬 WhatsApp</a>
          </div>
        </div>
      </footer>

      <HelpContact />
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/layout.tsx
echo "   ✅"

# ---------- 8. Middleware update ----------
echo ""
echo "🔒 [8/9] Middleware update..."

cat > middleware.ts <<'EOF'
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

async function verifySessionEdge(token: string, secret: string): Promise<boolean> {
  try {
    if (!token || !secret) return false;
    const parts = token.split('.');
    if (parts.length !== 2) return false;
    const [data, sig] = parts;

    const pad = (s: string) => s + '='.repeat((4 - (s.length % 4)) % 4);
    const b64urlToBytes = (s: string) => {
      const b64 = pad(s.replace(/-/g, '+').replace(/_/g, '/'));
      const bin = atob(b64);
      const bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      return bytes;
    };

    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
    );

    const valid = await crypto.subtle.verify('HMAC', key, b64urlToBytes(sig), enc.encode(data));
    if (!valid) return false;

    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(data)));
    if (!payload.ts || Date.now() - payload.ts > 30 * 24 * 60 * 60 * 1000) return false;
    return true;
  } catch {
    return false;
  }
}

export async function middleware(req: NextRequest) {
  const token = req.cookies.get('ec_session')?.value;
  const secret = process.env.SESSION_SECRET || '';
  const ok = await verifySessionEdge(token || '', secret);

  if (!ok) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', req.nextUrl.pathname);
    const res = NextResponse.redirect(url);
    res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
    return res;
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/team/:path*',
    '/account/:path*',
  ],
};
EOF
sed -i 's/\r$//' middleware.ts
echo "   ✅"

# ---------- 9. Verify + Push ----------
echo ""
echo "🔎 [9/9] Verify + push..."

# Check files
FILES=(
  "app/globals.css"
  "app/page.tsx"
  "app/login/page.tsx"
  "components/nav.tsx"
  "components/help-contact.tsx"
  "components/reveal.tsx"
  "app/dashboard/layout.tsx"
  "app/(protected)/layout.tsx"
  "middleware.ts"
)
for f in "${FILES[@]}"; do
  [ -f "$f" ] && echo "   ✅ $f" || echo "   ❌ MISSING: $f"
done

# Git
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "UI: Cosmic premium redesign + nav everywhere + help contact"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ COSMIC PREMIUM REDESIGN COMPLETE"
echo "==================================================="
echo ""
echo "🎨 THEME: Deep Obsidian + Electric Blue"
echo ""
echo "   Base:       #06070d (deep space black)"
echo "   Accent:     #4f9cff (electric blue)"
echo "   Secondary:  #7c5cff (violet)"
echo "   Emerald:    #30d158 (success)"
echo "   Amber:      #ff9f0a (warning)"
echo "   NO PINK ✓"
echo ""
echo "✨ EFFECTS ACTIVE:"
echo "   • Starfield background (drifting particles)"
echo "   • Aurora gradient mesh"
echo "   • Glass morphism (24px blur)"
echo "   • 3D tilt (2-degree perspective)"
echo "   • Border gradients (masked)"
echo "   • Scroll-triggered reveals"
echo "   • Floating help button (glow)"
echo "   • Animated badge dots"
echo ""
echo "🧭 NAVIGATION:"
echo "   ✅ Back button (top-left, on every page)"
echo "   ✅ Logo → dashboard"
echo "   ✅ 7 links + active highlight"
echo "   ✅ User avatar + role badge"
echo "   ✅ Sign out"
echo "   ✅ Mobile hamburger menu"
echo ""
echo "📞 HELP CONTACT:"
echo "   ✅ Floating button (bottom-right)"
echo "   ✅ Click → panel with Call + WhatsApp"
echo "   ✅ DIPEN ZALA · 8128931029"
echo "   ✅ Footer contact on every page"
echo ""
echo "📄 PAGES WITH NAV:"
echo "   ✅ /dashboard"
echo "   ✅ /senders"
echo "   ✅ /senders/rotation"
echo "   ✅ /anti-spam"
echo "   ✅ /team"
echo "   ✅ /account/sessions"
echo "   ✅ /history"
echo "   ✅ /campaigns/[id]"
echo ""
echo "⏱️  Vercel 2-3 min me deploy karega"
echo ""
echo "📸 TEST after deploy:"
echo "   1. https://emailcampaign-ten.vercel.app/"
echo "   2. Login karo"
echo "   3. Har page pe nav dikhe"
echo "   4. Back button kaam kare"
echo "   5. Help button bottom-right pe"
echo "==================================================="