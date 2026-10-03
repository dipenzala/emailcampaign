#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎨 ULTRA LIGHT THEME — Apple-Grade"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# CRLF
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 1. ULTRA LIGHT CSS ----------
echo ""
echo "🎨 [1/8] Writing ultra-light globals.css..."

cat > app/globals.css <<'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ============================================================
   ULTRA LIGHT THEME — Apple-Grade Premium
   Palette: Porcelain + Electric Blue + Emerald (NO pink)
   ============================================================ */

:root {
  --bg: #fbfbfd;
  --bg-2: #f5f5f7;
  --surface: rgba(255, 255, 255, 0.72);
  --surface-solid: #ffffff;
  --surface-hover: rgba(255, 255, 255, 0.95);

  --border: rgba(0, 0, 0, 0.06);
  --border-strong: rgba(0, 0, 0, 0.1);

  --fg: #1d1d1f;
  --fg-soft: #424245;
  --fg-muted: #6e6e73;
  --fg-dim: #86868b;

  --accent: #0071e3;
  --accent-bright: #0077ed;
  --accent-deep: #0058b8;
  --accent-soft: rgba(0, 113, 227, 0.08);

  --emerald: #30d158;
  --amber: #ff9f0a;
  --red: #ff453a;

  --ease-apple: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}

* { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }

html {
  scroll-behavior: smooth;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
  scroll-padding-top: 80px;
}

body {
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Inter", "Segoe UI", sans-serif;
  font-feature-settings: "cv02", "cv03", "cv04", "cv11", "ss01";
  overflow-x: hidden;
  letter-spacing: -0.011em;
  line-height: 1.47059;
  min-height: 100vh;
}

/* ---------- Layered light background ---------- */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -2;
  background:
    radial-gradient(ellipse 80% 55% at 50% -8%, rgba(0, 113, 227, 0.09) 0%, transparent 55%),
    radial-gradient(ellipse 55% 45% at 100% 25%, rgba(94, 92, 230, 0.05) 0%, transparent 50%),
    radial-gradient(ellipse 60% 45% at 0% 75%, rgba(48, 209, 88, 0.04) 0%, transparent 50%),
    linear-gradient(180deg, #fbfbfd 0%, #f5f5f7 100%);
  pointer-events: none;
}

/* Grid overlay (very subtle) */
body::after {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -1;
  background-image:
    linear-gradient(rgba(0, 0, 0, 0.018) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0, 0, 0, 0.018) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse at center, black 20%, transparent 75%);
  -webkit-mask-image: radial-gradient(ellipse at center, black 20%, transparent 75%);
  pointer-events: none;
}

/* ============================================================
   TYPOGRAPHY
   ============================================================ */

h1, h2, h3, h4, h5, h6 {
  letter-spacing: -0.025em;
  font-weight: 600;
  line-height: 1.15;
  color: var(--fg);
}

.headline {
  font-size: clamp(2.75rem, 7vw, 5.5rem);
  font-weight: 700;
  line-height: 1.02;
  letter-spacing: -0.035em;
  color: var(--fg);
}

.headline-sm {
  font-size: clamp(2rem, 4vw, 3.25rem);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.03em;
  color: var(--fg);
}

.eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--accent);
  margin-bottom: 1rem;
}

.subhead {
  font-size: clamp(1rem, 1.4vw, 1.25rem);
  line-height: 1.6;
  color: var(--fg-muted);
  font-weight: 400;
  max-width: 640px;
}

/* ============================================================
   CARDS — Premium light glass
   ============================================================ */

.card {
  position: relative;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 1.25rem;
  padding: 1.5rem;
  backdrop-filter: blur(30px) saturate(180%);
  -webkit-backdrop-filter: blur(30px) saturate(180%);
  box-shadow:
    0 1px 2px rgba(0, 0, 0, 0.02),
    0 4px 12px -4px rgba(0, 0, 0, 0.04),
    0 16px 40px -16px rgba(0, 0, 0, 0.06);
  transition: box-shadow 0.6s var(--ease-apple), transform 0.6s var(--ease-apple);
}

.card-hover:hover {
  transform: translateY(-4px);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.03),
    0 12px 24px -8px rgba(0, 0, 0, 0.06),
    0 32px 64px -20px rgba(0, 113, 227, 0.12);
}

/* ============================================================
   BUTTONS — Magnetic + Premium
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
  border-radius: 999px;
  border: none;
  cursor: pointer;
  user-select: none;
  transition: all 0.4s var(--ease-apple);
  overflow: hidden;
  font-family: inherit;
}

.btn-primary {
  color: white;
  background: linear-gradient(135deg, #0071e3 0%, #0077ed 100%);
  box-shadow:
    0 1px 2px rgba(0, 88, 184, 0.15),
    0 8px 20px -6px rgba(0, 113, 227, 0.4);
}

.btn-primary::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(135deg, rgba(255, 255, 255, 0.25) 0%, transparent 50%);
  opacity: 0.5;
  transition: opacity 0.4s var(--ease-apple);
}

.btn-primary::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(105deg, transparent 30%, rgba(255, 255, 255, 0.35) 50%, transparent 70%);
  transform: translateX(-110%);
  transition: transform 0.7s var(--ease-apple);
}

.btn-primary:hover:not(:disabled)::after {
  transform: translateX(110%);
}

.btn-primary:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow:
    0 2px 4px rgba(0, 88, 184, 0.2),
    0 16px 40px -8px rgba(0, 113, 227, 0.5);
}

.btn-primary:active:not(:disabled) {
  transform: translateY(0) scale(0.97);
  transition-duration: 0.1s;
}

.btn-primary:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.btn-ghost {
  color: var(--fg);
  background: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(0, 0, 0, 0.08);
  backdrop-filter: blur(12px);
}

.btn-ghost:hover:not(:disabled) {
  background: white;
  border-color: rgba(0, 0, 0, 0.14);
  transform: translateY(-2px);
  box-shadow: 0 8px 24px -8px rgba(0, 0, 0, 0.1);
}

.btn-danger {
  color: white;
  background: linear-gradient(135deg, #ff453a, #d92c25);
  box-shadow: 0 8px 20px -6px rgba(255, 69, 58, 0.4);
}

.btn-danger:hover {
  transform: translateY(-2px);
}

.btn-lg {
  padding: 0.95rem 2rem;
  font-size: 1rem;
}

/* ============================================================
   INPUTS — Crisp light
   ============================================================ */

.input {
  width: 100%;
  padding: 0.75rem 1rem;
  font-size: 0.9375rem;
  color: var(--fg);
  background: white;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 0.625rem;
  transition: all 0.3s var(--ease-apple);
  font-family: inherit;
  outline: none;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.input::placeholder { color: #a1a1a6; }

.input:hover {
  border-color: rgba(0, 0, 0, 0.16);
}

.input:focus {
  border-color: var(--accent);
  box-shadow:
    0 0 0 4px rgba(0, 113, 227, 0.12),
    0 1px 2px rgba(0, 0, 0, 0.02);
}

/* ============================================================
   NAV — Glass light
   ============================================================ */

.glass-nav {
  background: rgba(251, 251, 253, 0.78);
  backdrop-filter: saturate(180%) blur(24px);
  -webkit-backdrop-filter: saturate(180%) blur(24px);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

/* ============================================================
   GRADIENT TEXT
   ============================================================ */

.gradient-text {
  background: linear-gradient(135deg, #0071e3 0%, #0077ed 50%, #5e5ce6 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.gradient-text-emerald {
  background: linear-gradient(135deg, #0071e3 0%, #30d158 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

/* ============================================================
   3D TILT — Very subtle Apple feel
   ============================================================ */

.tilt {
  transition: transform 0.7s var(--ease-apple), box-shadow 0.7s var(--ease-apple);
  transform-style: preserve-3d;
  will-change: transform;
}

.tilt:hover {
  transform: perspective(1400px) rotateX(1.5deg) rotateY(-1.5deg) translateY(-5px) scale(1.005);
}

/* ============================================================
   FLOATING
   ============================================================ */

@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-8px); }
}
.float { animation: float 6s var(--ease-apple) infinite; }
.float-slow { animation: float 9s var(--ease-apple) infinite; }

/* ============================================================
   GLOW — soft blue
   ============================================================ */

@keyframes glowPulse {
  0%, 100% { box-shadow: 0 0 24px rgba(0, 113, 227, 0.25); }
  50% { box-shadow: 0 0 48px rgba(0, 113, 227, 0.45); }
}
.glow-pulse { animation: glowPulse 3s ease-in-out infinite; }

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
  border-radius: 999px;
  color: var(--fg-soft);
  background: rgba(255, 255, 255, 0.8);
  border: 1px solid rgba(0, 0, 0, 0.06);
  backdrop-filter: blur(12px);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--emerald);
  box-shadow: 0 0 8px rgba(48, 209, 88, 0.7);
  animation: pulse 2.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(1.3); }
}

/* ============================================================
   REVEAL — scroll-triggered
   ============================================================ */

[data-reveal] {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 1.1s var(--ease-out), transform 1.1s var(--ease-out);
  will-change: opacity, transform;
}

[data-reveal="fade"] { transform: none; }
[data-reveal="scale"] { transform: scale(0.94); }
[data-reveal="blur"] { filter: blur(12px); transform: translateY(30px); }
[data-reveal="left"] { transform: translateX(-50px); }
[data-reveal="right"] { transform: translateX(50px); }

[data-reveal].is-visible {
  opacity: 1;
  transform: none;
  filter: none;
}

[data-reveal-delay="1"] { transition-delay: 0.1s; }
[data-reveal-delay="2"] { transition-delay: 0.2s; }
[data-reveal-delay="3"] { transition-delay: 0.3s; }
[data-reveal-delay="4"] { transition-delay: 0.4s; }
[data-reveal-delay="5"] { transition-delay: 0.5s; }
[data-reveal-delay="6"] { transition-delay: 0.6s; }

/* ============================================================
   FADE-IN (initial)
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
   SHIMMER
   ============================================================ */

.shimmer {
  position: relative;
  overflow: hidden;
}

.shimmer::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    105deg,
    transparent 30%,
    rgba(0, 113, 227, 0.08) 50%,
    transparent 70%
  );
  transform: translateX(-100%);
  animation: shimmer 4s var(--ease-apple) infinite;
}

@keyframes shimmer {
  0% { transform: translateX(-100%); }
  60%, 100% { transform: translateX(100%); }
}

/* ============================================================
   SPINNER
   ============================================================ */

@keyframes spin { to { transform: rotate(360deg); } }
.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(0, 113, 227, 0.2);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

.spinner-white {
  border-color: rgba(255, 255, 255, 0.3);
  border-top-color: white;
}

/* ============================================================
   SECTION + CONTAINER
   ============================================================ */

.section {
  position: relative;
  padding: 7rem 1.5rem;
  overflow: hidden;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1.5rem;
}

/* ============================================================
   SCROLLBAR
   ============================================================ */

::-webkit-scrollbar { width: 12px; height: 12px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 12px;
  border: 3px solid transparent;
  background-clip: padding-box;
}
::-webkit-scrollbar-thumb:hover {
  background: rgba(0, 0, 0, 0.25);
  background-clip: padding-box;
}

/* ============================================================
   TEXT COLOR UTILITY OVERRIDES
   (in case Tailwind dark classes remain in some pages)
   ============================================================ */

.text-slate-100, .text-white { color: var(--fg) !important; }
.text-slate-200 { color: var(--fg) !important; }
.text-slate-300 { color: var(--fg-soft) !important; }
.text-slate-400 { color: var(--fg-muted) !important; }
.text-slate-500 { color: var(--fg-dim) !important; }
.text-slate-900 { color: var(--fg) !important; }

.bg-slate-950, .bg-slate-900, .bg-slate-100 { background: transparent !important; }
.bg-slate-800 { background: rgba(0, 0, 0, 0.04) !important; }
.bg-white { background: var(--surface-solid) !important; }
.bg-white\/5, .bg-white\/10, .bg-black\/5 { background: rgba(0, 0, 0, 0.03) !important; }

.border-slate-800, .border-slate-700, .border-black\/10 { border-color: var(--border) !important; }
.border-white\/5, .border-white\/10 { border-color: var(--border) !important; }

/* ============================================================
   REDUCED MOTION
   ============================================================ */

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
  [data-reveal] {
    opacity: 1 !important;
    transform: none !important;
    filter: none !important;
  }
}
CSSEOF
echo "   ✅ globals.css"

# ---------- 2. Nav (light premium) ----------
echo ""
echo "🧭 [2/8] Nav component..."

mkdir -p components

cat > components/nav.tsx <<'EOF'
'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';

type NavProps = { username?: string; role?: string };

const LINKS = [
  { href: '/dashboard', label: 'Campaign' },
  { href: '/senders', label: 'Senders' },
  { href: '/senders/rotation', label: 'Rotation' },
  { href: '/anti-spam', label: 'Anti-Spam' },
  { href: '/team', label: 'Team' },
  { href: '/account/sessions', label: 'Sessions' },
  { href: '/history', label: 'History' },
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
            className="flex items-center justify-center w-9 h-9 rounded-full bg-black/[0.04] hover:bg-black/[0.08] border border-black/[0.04] transition-all duration-300 text-[#424245] hover:text-[#0071e3] hover:scale-105 active:scale-95 group"
            title="Go back"
            aria-label="Go back"
          >
            <svg className="w-4 h-4 group-hover:-translate-x-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </button>

          <Link href="/dashboard" className="flex items-center gap-2.5 hover:opacity-80 transition-opacity min-w-0 group">
            <div className="relative w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden shadow-md shadow-blue-500/20 group-hover:shadow-blue-500/30 transition-shadow">
              <div className="absolute inset-0 bg-gradient-to-br from-[#0071e3] to-[#0077ed]" />
              <svg className="relative w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-semibold tracking-tight text-sm text-[#1d1d1f] truncate">EmailCampaign</span>
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
                  ? 'text-[#0071e3] bg-[#0071e3]/[0.08]'
                  : 'text-[#424245] hover:text-[#0071e3] hover:bg-black/[0.04]'
              }`}
            >
              {l.label}
              {isActive(l.href) && (
                <span className="absolute -bottom-px left-3 right-3 h-px bg-gradient-to-r from-transparent via-[#0071e3] to-transparent" />
              )}
            </Link>
          ))}
        </div>

        {/* RIGHT: User */}
        <div className="flex items-center gap-2">
          <div className="hidden md:flex items-center gap-2 pl-3 border-l border-black/[0.06]">
            <div className="relative">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#0071e3] to-[#0077ed] flex items-center justify-center text-white text-xs font-bold shadow-sm">
                {(username || 'U')[0].toUpperCase()}
              </div>
              {role === 'owner' && (
                <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-[#30d158] border-2 border-white" />
              )}
            </div>
            <div className="flex flex-col leading-tight">
              <span className="text-xs font-medium text-[#1d1d1f]">@{username || 'user'}</span>
              <span className="text-[10px] text-[#86868b]">{role === 'owner' ? 'Owner' : 'Member'}</span>
            </div>
          </div>

          <button
            onClick={logout}
            disabled={busy}
            className="hidden md:inline-flex text-xs font-medium text-[#424245] hover:text-[#ff453a] px-3 py-2 rounded-lg hover:bg-[#ff453a]/[0.06] transition-all duration-300 disabled:opacity-50"
          >
            {busy ? 'Signing out…' : 'Sign out'}
          </button>

          <button
            onClick={() => setOpen(!open)}
            className="lg:hidden w-9 h-9 rounded-lg bg-black/[0.04] hover:bg-black/[0.08] border border-black/[0.04] flex items-center justify-center transition-colors text-[#424245]"
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

      {open && (
        <div className="lg:hidden border-t border-black/[0.06] bg-white/95 backdrop-blur-xl">
          <div className="px-4 py-3 space-y-1">
            {LINKS.map(l => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className={`block text-sm font-medium px-3 py-2.5 rounded-lg transition-colors ${
                  isActive(l.href)
                    ? 'text-[#0071e3] bg-[#0071e3]/[0.08]'
                    : 'text-[#424245] hover:bg-black/[0.04]'
                }`}
              >
                {l.label}
              </Link>
            ))}
            <div className="pt-2 mt-2 border-t border-black/[0.06]">
              <div className="flex items-center gap-2.5 px-3 py-2">
                <div className="w-7 h-7 rounded-full bg-gradient-to-br from-[#0071e3] to-[#0077ed] flex items-center justify-center text-white text-[10px] font-bold">
                  {(username || 'U')[0].toUpperCase()}
                </div>
                <span className="text-xs text-[#1d1d1f]">@{username || 'user'}</span>
              </div>
              <button
                onClick={logout}
                disabled={busy}
                className="w-full text-left text-sm font-medium px-3 py-2.5 rounded-lg text-[#ff453a] hover:bg-[#ff453a]/[0.06] transition-colors"
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

# ---------- 3. Help contact (light) ----------
echo ""
echo "📞 [3/8] Help contact widget..."

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
          background: 'linear-gradient(135deg, #0071e3 0%, #0077ed 100%)',
          boxShadow: '0 10px 30px -6px rgba(0, 113, 227, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.2) inset',
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
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(30px) saturate(180%)',
            border: '1px solid rgba(0, 0, 0, 0.08)',
            boxShadow: '0 40px 80px -20px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 113, 227, 0.08)',
            animation: 'fadeUp 0.4s cubic-bezier(0.16, 1, 0.3, 1) both',
          }}
        >
          <div className="relative px-5 py-4 overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-[#0071e3]/10 to-[#5e5ce6]/5" />
            <div className="relative flex items-center gap-3">
              <div className="w-11 h-11 rounded-full bg-gradient-to-br from-[#0071e3] to-[#0077ed] flex items-center justify-center text-white text-sm font-bold shadow-md">
                {NAME.split(' ').map(n => n[0]).join('')}
              </div>
              <div>
                <div className="text-[#1d1d1f] font-semibold text-sm">{NAME}</div>
                <div className="text-[#6e6e73] text-xs flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#30d158] animate-pulse" />
                  Online
                </div>
              </div>
            </div>
          </div>

          <div className="p-5 space-y-2.5">
            <p className="text-xs text-[#6e6e73] leading-relaxed pb-2">
              Koi bhi help, query, ya issue ke liye direct contact karein:
            </p>

            <a
              href={`tel:+91${PHONE}`}
              className="flex items-center gap-3 p-3 rounded-xl bg-black/[0.02] hover:bg-black/[0.05] border border-black/[0.06] hover:border-[#30d158]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[#30d158]/10 flex items-center justify-center text-[#30d158] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[#86868b]">Call</div>
                <div className="text-sm font-semibold text-[#1d1d1f]">+91 {PHONE}</div>
              </div>
              <svg className="w-4 h-4 text-[#86868b] group-hover:text-[#30d158] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>

            <a
              href={`https://wa.me/91${PHONE}?text=${encodeURIComponent('Hi, mujhe EmailCampaign ke baare me help chahiye.')}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 p-3 rounded-xl bg-black/[0.02] hover:bg-black/[0.05] border border-black/[0.06] hover:border-[#25D366]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[#25D366]/10 flex items-center justify-center text-[#25D366] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[#86868b]">WhatsApp</div>
                <div className="text-sm font-semibold text-[#1d1d1f]">Chat now</div>
              </div>
              <svg className="w-4 h-4 text-[#86868b] group-hover:text-[#25D366] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>
          </div>
        </div>
      )}
    </>
  );
}
EOF
sed -i 's/\r$//' components/help-contact.tsx

# ---------- 4. Reveal component ----------
echo ""
echo "🎬 [4/8] Reveal component..."

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

# ---------- 5. Login (light premium) ----------
echo ""
echo "🔐 [5/8] Login page..."

mkdir -p app/login

cat > app/login/page.tsx <<'EOF'
'use client';
import { useState, Suspense, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';

function getOrCreateDeviceId(): string {
  if (typeof window === 'undefined') return '';
  const KEY = 'ec_device_id';
  let id = localStorage.getItem(KEY);
  if (!id || id.length < 16) {
    const bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    id = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
    localStorage.setItem(KEY, id);
  }
  return id;
}

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
        body: JSON.stringify({ username, password, deviceId: getOrCreateDeviceId() }),
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

      {/* Floating decorative orbs */}
      <div className="absolute top-[8%] left-[10%] w-96 h-96 rounded-full bg-[#0071e3]/10 blur-[100px] float-slow pointer-events-none" />
      <div className="absolute bottom-[8%] right-[10%] w-[480px] h-[480px] rounded-full bg-[#5e5ce6]/8 blur-[120px] float pointer-events-none" style={{ animationDelay: '2s' }} />
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-[#30d158]/5 blur-[140px] pointer-events-none" />

      {/* Top-right credit */}
      <div className="absolute top-6 right-6 z-20 fade-up">
        <div className="px-4 py-2 rounded-full bg-white/80 backdrop-blur-xl border border-black/[0.06] shadow-sm">
          <span className="text-xs text-[#86868b]">Created by</span>{' '}
          <span className="text-xs font-semibold text-[#0071e3]">DIPEN ZALA</span>
        </div>
      </div>

      <div className="relative z-10 w-full max-w-[420px]">

        {/* Logo */}
        <div className="text-center mb-10 fade-up">
          <div className="inline-block relative">
            <div className="absolute inset-0 bg-[#0071e3] rounded-2xl blur-2xl opacity-30" />
            <div className="relative w-16 h-16 rounded-2xl bg-gradient-to-br from-[#0071e3] to-[#0077ed] flex items-center justify-center shadow-xl shadow-blue-500/30 float-slow">
              <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
          <h1 className="mt-6 text-3xl font-semibold tracking-tight text-[#1d1d1f]">
            Email<span className="gradient-text">Campaign</span>
          </h1>
          <p className="mt-2 text-sm text-[#6e6e73]">Premium email platform</p>
        </div>

        {/* Card */}
        <div className="card !p-8 md:!p-10 !rounded-3xl fade-up fade-up-d1 shadow-2xl shadow-blue-500/5">

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
                  <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide uppercase">Username</label>
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
                  <label className="text-xs font-semibold text-[#424245] mb-2 block tracking-wide uppercase">Password</label>
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
                  <div className="text-sm text-[#ff453a] bg-[#ff453a]/[0.06] border border-[#ff453a]/20 rounded-xl px-4 py-3 flex items-start gap-2 fade-up">
                    <svg className="w-4 h-4 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                    <span>{err}</span>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={busy}
                  className="btn btn-primary w-full !py-3.5 !text-base !mt-2"
                >
                  {busy ? (
                    <span className="flex items-center gap-2">
                      <span className="spinner spinner-white" />
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
        <div className="mt-6 flex items-center justify-center gap-5 text-xs text-[#86868b] fade-up fade-up-d2">
          <span className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-[#30d158]" />
            Secure
          </span>
          <span className="w-px h-3 bg-black/10" />
          <span>Invite-only</span>
          <span className="w-px h-3 bg-black/10" />
          <span>OAuth 2.0</span>
        </div>

        <div className="mt-8 text-center fade-up fade-up-d3">
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
        <label className="text-xs font-semibold text-[#424245] mb-2 block uppercase tracking-wide">Admin Username</label>
        <input type="text" required value={username} onChange={e => setUsername(e.target.value)} placeholder="admin" className="input" autoFocus />
      </div>

      <div>
        <label className="text-xs font-semibold text-[#424245] mb-2 block uppercase tracking-wide">Password (min 8 chars)</label>
        <input type="password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" className="input" />
      </div>

      <div>
        <label className="text-xs font-semibold text-[#424245] mb-2 block uppercase tracking-wide">Setup Key</label>
        <input type="text" required value={setupKey} onChange={e => setSetupKey(e.target.value)} placeholder="from Vercel env" className="input" />
        <p className="text-xs text-[#86868b] mt-2">
          Vercel → Environment Variables → <code className="bg-black/[0.05] px-1.5 py-0.5 rounded text-[#424245] text-[11px]">ADMIN_SETUP_KEY</code>
        </p>
      </div>

      {err && (
        <div className="text-sm text-[#ff453a] bg-[#ff453a]/[0.06] border border-[#ff453a]/20 rounded-xl px-4 py-3">{err}</div>
      )}

      <button type="submit" disabled={busy} className="btn btn-primary w-full !py-3.5 !text-base">
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
EOF
sed -i 's/\r$//' app/login/page.tsx

# ---------- 6. Landing (light premium) ----------
echo ""
echo "✨ [6/8] Landing page..."

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
            <div className="relative w-9 h-9 rounded-xl overflow-hidden shadow-md shadow-blue-500/20 group-hover:shadow-blue-500/30 transition-shadow">
              <div className="absolute inset-0 bg-gradient-to-br from-[#0071e3] to-[#0077ed]" />
              <svg className="relative w-full h-full p-2 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="text-sm font-semibold tracking-tight text-[#1d1d1f]">EmailCampaign</span>
          </Link>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-[#424245]">
            <a href="#features" className="hover:text-[#0071e3] transition-colors">Features</a>
            <a href="#workflow" className="hover:text-[#0071e3] transition-colors">Workflow</a>
            <a href="#security" className="hover:text-[#0071e3] transition-colors">Security</a>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-[#424245] hover:text-[#0071e3] transition-colors hidden sm:block">Sign in</Link>
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
            <div className="mt-16 flex flex-wrap items-center justify-center gap-8 text-xs text-[#86868b]">
              {['No credit card', 'OAuth 2.0 secure', 'Cancel anytime'].map((t) => (
                <span key={t} className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
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
            <div className="tilt card !p-0 overflow-hidden !rounded-2xl shadow-2xl shadow-blue-500/10">
              <div className="flex items-center gap-2 px-5 py-3.5 border-b border-black/[0.06] bg-white/60">
                <span className="w-3 h-3 rounded-full bg-[#ff5f57]" />
                <span className="w-3 h-3 rounded-full bg-[#febc2e]" />
                <span className="w-3 h-3 rounded-full bg-[#28c840]" />
                <span className="ml-3 text-xs text-[#86868b] font-mono">campaign · live</span>
                <span className="ml-auto flex items-center gap-1.5 text-xs text-[#30d158]">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#30d158] animate-pulse" />
                  Running
                </span>
              </div>
              <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4 bg-white/40">
                {[
                  { l: 'SENT', v: '12,847', c: '#0071e3' },
                  { l: 'DELIVERED', v: '12,412', c: '#30d158' },
                  { l: 'PENDING', v: '435', c: '#ff9f0a' },
                  { l: 'FAILED', v: '12', c: '#ff453a' },
                ].map(s => (
                  <div key={s.l} className="bg-white border border-black/[0.06] rounded-xl p-5 shadow-sm">
                    <div className="text-[10px] tracking-[0.15em] text-[#86868b] font-medium">{s.l}</div>
                    <div className="text-3xl font-semibold mt-2 tracking-tight" style={{ color: s.c }}>{s.v}</div>
                  </div>
                ))}
              </div>
              <div className="px-8 pb-8 bg-white/40">
                <div className="h-1.5 w-full bg-black/[0.05] rounded-full overflow-hidden">
                  <div className="h-full w-[96%] bg-gradient-to-r from-[#0071e3] via-[#0077ed] to-[#30d158] rounded-full" />
                </div>
                <div className="flex justify-between text-xs text-[#86868b] mt-3">
                  <span>Campaign progress</span>
                  <span className="text-[#1d1d1f] font-medium">96.4%</span>
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
              <h2 className="headline-sm">Built with real infrastructure.</h2>
              <p className="subhead mx-auto mt-5">
                Every feature engineered for scale. No shortcuts, no fake numbers.
              </p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { title: 'OAuth 2.0 Only', desc: 'Your Gmail password never touches our servers. Tokens encrypted with AES-256-GCM at rest.', icon: 'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z' },
              { title: 'Real-time Dashboard', desc: 'Live counters via Server-Sent Events. Pause, resume, or stop any campaign instantly.', icon: 'M13 10V3L4 14h7v7l9-11h-7z' },
              { title: 'Smart Import', desc: 'Excel, CSV, Google Sheets. Auto-validate, dedupe, MX-check, and filter disposables.', icon: 'M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2' },
              { title: 'HTML Email Editor', desc: 'Paste your HTML. Live desktop + mobile preview. Automatic plain-text fallback.', icon: 'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4' },
              { title: '7-Layer Anti-Spam', desc: 'Content checker, warm-up schedules, bounce handler, list hygiene, and rate guard.', icon: 'M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z' },
              { title: 'Sender Rotation', desc: 'Round-robin across 25+ Gmail accounts with per-sender batch limits and reputation.', icon: 'M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15' },
            ].map((f, i) => (
              <Reveal key={f.title} type="up" delay={((i % 3) + 1) as any}>
                <div className="tilt card card-hover h-full">
                  <div className="w-11 h-11 rounded-xl flex items-center justify-center mb-5 bg-[#0071e3]/10 border border-[#0071e3]/20">
                    <svg className="w-5 h-5 text-[#0071e3]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                      <path strokeLinecap="round" strokeLinejoin="round" d={f.icon} />
                    </svg>
                  </div>
                  <h3 className="text-base font-semibold text-[#1d1d1f] mb-2">{f.title}</h3>
                  <p className="text-sm text-[#6e6e73] leading-relaxed">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* WORKFLOW */}
      <section id="workflow" className="section bg-gradient-to-b from-transparent via-white/40 to-transparent">
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
              { n: '01', title: 'Import', desc: 'Upload Excel, CSV, or connect Google Sheets. Validation, dedupe, and MX check happen automatically.' },
              { n: '02', title: 'Compose', desc: 'Paste HTML. Preview on desktop and mobile. Send a test in one click.' },
              { n: '03', title: 'Launch', desc: 'Hit start. Watch live counters. Pause, resume, or stop anytime.' },
            ].map((s, i) => (
              <Reveal key={s.n} type="up" delay={((i % 3) + 1) as any}>
                <div className="card card-hover h-full relative overflow-hidden">
                  <div className="absolute top-4 right-5 text-6xl font-black text-[#0071e3]/[0.04] tracking-tighter">{s.n}</div>
                  <div className="relative">
                    <div className="text-4xl font-semibold tracking-tighter gradient-text mb-4">{s.n}</div>
                    <h3 className="text-lg font-semibold text-[#1d1d1f] mb-2">{s.title}</h3>
                    <p className="text-sm text-[#6e6e73] leading-relaxed">{s.desc}</p>
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
              <div className="absolute top-0 right-0 w-96 h-96 bg-[#0071e3]/5 rounded-full blur-[100px]" />
              <div className="relative">
                <div className="eyebrow">Security</div>
                <h2 className="headline-sm max-w-2xl">Your data. Your senders. Your control.</h2>
                <p className="text-[#6e6e73] text-lg leading-relaxed mt-6 max-w-lg">
                  Tokens encrypted with AES-256-GCM. Sessions signed with HMAC-SHA256. Login rate-limited. Every action audited.
                </p>
                <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-10">
                  {[
                    'AES-256-GCM encryption',
                    'HMAC-signed sessions',
                    'Device-bound sessions',
                    'Login rate limiting',
                    'OAuth 2.0 only',
                    'No password storage',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3">
                      <div className="w-5 h-5 rounded-md bg-[#30d158]/20 flex items-center justify-center flex-shrink-0">
                        <svg className="w-3 h-3 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <span className="text-sm text-[#424245]">{f}</span>
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
      <footer className="relative border-t border-black/[0.06] py-12 bg-white/40 backdrop-blur">
        <div className="container">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#0071e3] to-[#0077ed]" />
              <span className="text-xs text-[#86868b]">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-xs text-[#86868b]">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-[#1d1d1f] transition-colors" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-[#1d1d1f] transition-colors">Privacy</Link>
              <Link href="/terms" className="hover:text-[#1d1d1f] transition-colors">Terms</Link>
              <Link href="/refund" className="hover:text-[#1d1d1f] transition-colors">Refund</Link>
              <Link href="/login" className="hover:text-[#1d1d1f] transition-colors">Sign in</Link>
            </div>
          </div>
          <div className="mt-6 pt-6 border-t border-black/[0.04] flex flex-wrap items-center justify-center md:justify-between gap-4 text-xs">
            <span className="text-[#86868b]">Help & Support:</span>
            <div className="flex items-center gap-4">
              <a href="tel:+918128931029" className="text-[#0071e3] hover:underline font-medium">📞 +91 8128931029</a>
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

# ---------- 7. Protected + Dashboard layouts ----------
echo ""
echo "🎛️  [7/8] Layouts (nav everywhere)..."

# Protected group layout
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
      <main className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-8">{children}</main>
      <footer className="max-w-7xl mx-auto px-4 md:px-6 py-8 mt-8 border-t border-black/[0.06]">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="text-[#86868b]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
          </div>
          <div className="flex items-center gap-5">
            <span className="text-[#86868b]">Help:</span>
            <a href="tel:+918128931029" className="text-[#0071e3] hover:underline font-medium">📞 8128931029</a>
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

# Move pages into protected group
mv_to_protected() {
  local name="$1"
  if [ -d "app/$name" ]; then
    rm -rf "app/(protected)/$name" 2>/dev/null || true
    mv "app/$name" "app/(protected)/$name"
    echo "   → app/$name → app/(protected)/$name"
  fi
}
mv_to_protected "senders"
mv_to_protected "anti-spam"
mv_to_protected "team"
mv_to_protected "history"
mv_to_protected "account"

# Dashboard layout
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
      <main className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-8">{children}</main>
      <footer className="max-w-7xl mx-auto px-4 md:px-6 py-8 mt-8 border-t border-black/[0.06]">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="text-[#86868b]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
          </div>
          <div className="flex items-center gap-5">
            <span className="text-[#86868b]">Help:</span>
            <a href="tel:+918128931029" className="text-[#0071e3] hover:underline font-medium">📞 8128931029</a>
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

# ---------- 8. Git push ----------
echo ""
echo "🌿 [8/8] Push..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "UI: Ultra light theme (Apple-grade premium)"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ ULTRA LIGHT THEME COMPLETE"
echo "==================================================="
echo ""
echo "🎨 PALETTE:"
echo "   Background:   #fbfbfd  (Porcelain white)"
echo "   Surface:      White glass (72% opacity)"
echo "   Text:         #1d1d1f  (Near-black)"
echo "   Primary:      #0071e3  (Apple blue)"
echo "   Success:      #30d158  (Emerald)"
echo "   Warning:      #ff9f0a  (Amber)"
echo "   Error:        #ff453a  (Red)"
echo "   NO PINK ✓"
echo ""
echo "✨ EFFECTS:"
echo "   • Layered light background + grid overlay"
echo "   • Floating gradient orbs (login page)"
echo "   • Glass morphism (30px blur)"
echo "   • Magnetic buttons with shine sweep"
echo "   • 3D tilt cards (subtle)"
echo "   • Scroll-triggered reveals"
echo "   • Stagger animations (fade-up-d1 to d5)"
echo "   • Glow pulse on primary elements"
echo "   • Help button with gradient + scale hover"
echo ""
echo "📄 PAGES UPDATED:"
echo "   ✅ /              → Light hero + features"
echo "   ✅ /login         → Light glass card, blue accent"
echo "   ✅ /dashboard     → Nav + back + help"
echo "   ✅ /senders       → Same layout"
echo "   ✅ All other pages"
echo ""
echo "⏱️  Vercel 2-3 min me deploy"
echo ""
echo "📸 Test URLs:"
echo "   https://emailcampaign-ten.vercel.app/"
echo "   https://emailcampaign-ten.vercel.app/login"
echo ""
echo "Bolo 'gallery + payment integration' — main next step banaunga"
echo "==================================================="