#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎨 Apple-Inspired Premium Redesign"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 2. Premium CSS System ----------
echo ""
echo "🎨 [1/6] Writing premium globals.css..."

cat > app/globals.css <<'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ============================================================
   APPLE-INSPIRED PREMIUM DESIGN SYSTEM
   Palette: Slate · Blue · Indigo · Emerald
   Motion: Apple Cubic Bezier — 60fps smooth
   ============================================================ */

:root {
  --bg: #fbfbfd;
  --fg: #1d1d1f;
  --fg-soft: #424245;
  --fg-muted: #6e6e73;
  --accent: #0071e3;
  --accent-hover: #0077ed;
  --accent-deep: #0058b8;
  --indigo: #5e5ce6;
  --emerald: #30d158;
  --border: rgba(0, 0, 0, 0.08);
  --border-strong: rgba(0, 0, 0, 0.12);
  --card-bg: rgba(255, 255, 255, 0.72);

  /* Apple's actual motion curves */
  --ease-apple: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
  --ease-out-smooth: cubic-bezier(0.16, 1, 0.3, 1);
}

* { -webkit-tap-highlight-color: transparent; }

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
  font-feature-settings: "cv02", "cv03", "cv04", "cv11";
  overflow-x: hidden;
  letter-spacing: -0.011em;
  line-height: 1.47059;
}

/* ---------- Subtle mesh background ---------- */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -2;
  background:
    radial-gradient(ellipse 70% 50% at 20% 0%, rgba(0, 113, 227, 0.08) 0%, transparent 60%),
    radial-gradient(ellipse 60% 40% at 85% 20%, rgba(94, 92, 230, 0.06) 0%, transparent 55%),
    radial-gradient(ellipse 50% 40% at 50% 100%, rgba(48, 209, 88, 0.04) 0%, transparent 60%),
    #fbfbfd;
  pointer-events: none;
}

/* Grid overlay (very subtle) */
body::after {
  content: '';
  position: fixed;
  inset: 0;
  z-index: -1;
  background-image:
    linear-gradient(rgba(0, 0, 0, 0.015) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0, 0, 0, 0.015) 1px, transparent 1px);
  background-size: 64px 64px;
  pointer-events: none;
  mask-image: radial-gradient(ellipse at center, black 30%, transparent 75%);
  -webkit-mask-image: radial-gradient(ellipse at center, black 30%, transparent 75%);
}

/* ============================================================
   SCROLL-TRIGGERED REVEALS — Apple-style
   ============================================================ */

[data-reveal] {
  opacity: 0;
  transform: translateY(40px);
  transition:
    opacity 1.1s var(--ease-out-smooth),
    transform 1.1s var(--ease-out-smooth);
  will-change: opacity, transform;
}

[data-reveal="fade"] {
  transform: none;
}

[data-reveal="left"] {
  transform: translateX(-50px);
}

[data-reveal="right"] {
  transform: translateX(50px);
}

[data-reveal="scale"] {
  transform: scale(0.94);
}

[data-reveal="blur"] {
  filter: blur(12px);
  transform: translateY(30px);
}

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
   LAYOUT PRIMITIVES
   ============================================================ */

.section {
  position: relative;
  padding: 8rem 1.5rem;
  overflow: hidden;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1.5rem;
}

.eyebrow {
  display: inline-block;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
  margin-bottom: 1rem;
}

.headline {
  font-size: clamp(2.5rem, 6vw, 5rem);
  font-weight: 700;
  line-height: 1.05;
  letter-spacing: -0.03em;
  color: var(--fg);
}

.headline-sm {
  font-size: clamp(2rem, 4vw, 3rem);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.025em;
}

.subhead {
  font-size: clamp(1.125rem, 2vw, 1.5rem);
  line-height: 1.5;
  color: var(--fg-muted);
  font-weight: 400;
  max-width: 640px;
  margin: 1.5rem auto 0;
}

.body-text {
  font-size: 1rem;
  line-height: 1.6;
  color: var(--fg-soft);
}

/* ============================================================
   CARDS — Premium glass
   ============================================================ */

.card {
  background: var(--card-bg);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border: 1px solid var(--border);
  border-radius: 1.5rem;
  padding: 1.75rem;
  box-shadow:
    0 1px 2px rgba(0, 0, 0, 0.02),
    0 8px 24px -12px rgba(0, 0, 0, 0.08);
  transition: box-shadow 0.6s var(--ease-apple), transform 0.6s var(--ease-apple);
}

.card-hover:hover {
  transform: translateY(-4px);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.03),
    0 24px 48px -16px rgba(0, 0, 0, 0.14);
}

/* ============================================================
   BUTTONS — Apple-inspired
   ============================================================ */

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  font-size: 0.9375rem;
  font-weight: 500;
  letter-spacing: -0.01em;
  border-radius: 980px;
  border: none;
  cursor: pointer;
  user-select: none;
  transition: all 0.4s var(--ease-apple);
  white-space: nowrap;
}

.btn-primary {
  background: var(--accent);
  color: white;
  box-shadow: 0 4px 14px -4px rgba(0, 113, 227, 0.4);
}

.btn-primary:hover:not(:disabled) {
  background: var(--accent-hover);
  transform: translateY(-1px);
  box-shadow: 0 8px 24px -6px rgba(0, 113, 227, 0.5);
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
  background: rgba(0, 0, 0, 0.04);
  color: var(--fg);
  border: 1px solid transparent;
}

.btn-ghost:hover:not(:disabled) {
  background: rgba(0, 0, 0, 0.07);
  transform: translateY(-1px);
}

.btn-ghost:active:not(:disabled) {
  transform: scale(0.98);
}

.btn-danger {
  background: #ff3b30;
  color: white;
  box-shadow: 0 4px 14px -4px rgba(255, 59, 48, 0.4);
}

.btn-danger:hover {
  background: #ff2d20;
  transform: translateY(-1px);
}

.btn-lg {
  padding: 1rem 2rem;
  font-size: 1.0625rem;
}

/* ============================================================
   INPUTS — refined
   ============================================================ */

.input {
  width: 100%;
  padding: 0.875rem 1.125rem;
  font-size: 0.9375rem;
  color: var(--fg);
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid var(--border-strong);
  border-radius: 0.75rem;
  transition: all 0.3s var(--ease-apple);
  font-family: inherit;
}

.input::placeholder { color: #a1a1a6; }

.input:hover {
  border-color: rgba(0, 0, 0, 0.18);
}

.input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 4px rgba(0, 113, 227, 0.12);
  background: white;
}

/* ============================================================
   NAV — Apple blur bar
   ============================================================ */

.glass-nav {
  background: rgba(251, 251, 253, 0.72);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  transition: background 0.4s var(--ease-apple);
}

/* ============================================================
   GRADIENT TEXT — subtle, sophisticated
   ============================================================ */

.gradient-text {
  background: linear-gradient(135deg, #0071e3 0%, #5e5ce6 100%);
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
   3D TILT (very subtle, Apple-like)
   ============================================================ */

.tilt {
  transition: transform 0.7s var(--ease-apple), box-shadow 0.7s var(--ease-apple);
  transform-style: preserve-3d;
  will-change: transform;
}

.tilt:hover {
  transform: perspective(1400px) rotateX(1.5deg) rotateY(-1.5deg) translateY(-6px);
}

/* ============================================================
   FLOATING (very slow, elegant)
   ============================================================ */

@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-8px); }
}

.float { animation: float 6s var(--ease-apple) infinite; }
.float-slow { animation: float 9s var(--ease-apple) infinite; }

/* ============================================================
   PARALLAX LAYERS
   ============================================================ */

.parallax-slow {
  transition: transform 0.4s var(--ease-apple);
  will-change: transform;
}

/* ============================================================
   CINEMATIC SCALE REVEAL
   ============================================================ */

@keyframes cinematicReveal {
  0% {
    opacity: 0;
    transform: scale(1.08);
    filter: blur(20px);
  }
  100% {
    opacity: 1;
    transform: scale(1);
    filter: blur(0);
  }
}

.cinematic {
  animation: cinematicReveal 1.6s var(--ease-out-smooth) both;
}

/* ============================================================
   SOFT FADE-IN-UP (initial page load)
   ============================================================ */

@keyframes fadeUp {
  from {
    opacity: 0;
    transform: translateY(24px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.fade-up {
  animation: fadeUp 0.9s var(--ease-out-smooth) both;
}

.fade-up-delay-1 { animation-delay: 0.1s; }
.fade-up-delay-2 { animation-delay: 0.2s; }
.fade-up-delay-3 { animation-delay: 0.3s; }
.fade-up-delay-4 { animation-delay: 0.4s; }
.fade-up-delay-5 { animation-delay: 0.5s; }

/* ============================================================
   SHIMMER (very subtle highlight sweep)
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
    100deg,
    transparent 30%,
    rgba(0, 113, 227, 0.06) 50%,
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
   GLOW (soft, blue)
   ============================================================ */

.glow-blue {
  box-shadow:
    0 0 0 1px rgba(0, 113, 227, 0.1),
    0 8px 32px -8px rgba(0, 113, 227, 0.25);
}

/* ============================================================
   DIVIDERS
   ============================================================ */

.divider-soft {
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(0, 0, 0, 0.06), transparent);
}

/* ============================================================
   BADGE
   ============================================================ */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.875rem;
  font-size: 0.75rem;
  font-weight: 500;
  letter-spacing: -0.005em;
  border-radius: 980px;
  background: rgba(0, 113, 227, 0.08);
  color: var(--accent);
  border: 1px solid rgba(0, 113, 227, 0.12);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--emerald);
  box-shadow: 0 0 8px rgba(48, 209, 88, 0.6);
  animation: pulse 2.5s var(--ease-apple) infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
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
   REDUCED MOTION (accessibility)
   ============================================================ */

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
  [data-reveal] {
    opacity: 1 !important;
    transform: none !important;
    filter: none !important;
  }
}

/* ============================================================
   TEXT COLOR OVERRIDES (dark utility fix)
   ============================================================ */

.text-slate-100, .text-white { color: var(--fg) !important; }
.text-slate-200 { color: var(--fg) !important; }
.text-slate-300 { color: var(--fg-soft) !important; }
.text-slate-400 { color: var(--fg-muted) !important; }
.text-slate-500 { color: #86868b !important; }

.bg-slate-950, .bg-slate-900 { background-color: transparent !important; }
.bg-slate-800 { background-color: rgba(0, 0, 0, 0.04) !important; }
.bg-white\/5 { background-color: rgba(0, 0, 0, 0.03) !important; }
.bg-white\/10 { background-color: rgba(0, 0, 0, 0.05) !important; }
.border-slate-800, .border-slate-700 { border-color: var(--border) !important; }
.border-white\/5, .border-white\/10 { border-color: var(--border) !important; }
CSSEOF
echo "   ✅"

# ---------- 3. Reveal Hook (scroll-triggered) ----------
echo ""
echo "🎬 [2/6] Scroll reveal hook..."

mkdir -p components
cat > components/reveal.tsx <<'EOF'
'use client';
import { useEffect, useRef, ReactNode } from 'react';

/**
 * Scroll-triggered reveal wrapper.
 * IntersectionObserver + smooth CSS transitions = Apple-style reveal.
 */
export function Reveal({
  children,
  type = 'up',
  delay = 0,
  className = '',
  as: Tag = 'div',
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
      { threshold: 0.1, rootMargin: '0px 0px -80px 0px' }
    );

    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <Tag
      ref={ref}
      data-reveal={type}
      data-reveal-delay={delay || undefined}
      className={className}
    >
      {children}
    </Tag>
  );
}
EOF
sed -i 's/\r$//' components/reveal.tsx
echo "   ✅"

# ---------- 4. Parallax hook ----------
echo ""
echo "🎬 [3/6] Parallax hook..."

cat > components/parallax.tsx <<'EOF'
'use client';
import { useEffect, useRef, ReactNode } from 'react';

/**
 * Slow parallax scroll. Element moves at fraction of scroll speed.
 */
export function Parallax({
  children,
  speed = 0.15,
  className = '',
}: {
  children: ReactNode;
  speed?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let raf = 0;

    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const rect = el.getBoundingClientRect();
        const center = rect.top + rect.height / 2 - window.innerHeight / 2;
        el.style.transform = `translate3d(0, ${-center * speed}px, 0)`;
      });
    };

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', onScroll);
      cancelAnimationFrame(raf);
    };
  }, [speed]);

  return (
    <div ref={ref} className={className} style={{ willChange: 'transform' }}>
      {children}
    </div>
  );
}
EOF
sed -i 's/\r$//' components/parallax.tsx
echo "   ✅"

# ---------- 5. Premium Landing Page ----------
echo ""
echo "✨ [4/6] Premium landing page..."

cat > app/page.tsx <<'EOF'
import Link from 'next/link';
import { Reveal } from '@/components/reveal';
import { Parallax } from '@/components/parallax';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      {/* NAV */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="container flex items-center justify-between h-14">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-7 h-7 rounded-lg bg-[#0071e3] flex items-center justify-center">
              <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="text-sm font-semibold tracking-tight">EmailCampaign</span>
          </Link>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-[#424245]">
            <a href="#features" className="hover:text-[#0071e3] transition-colors">Features</a>
            <a href="#workflow" className="hover:text-[#0071e3] transition-colors">Workflow</a>
            <a href="#security" className="hover:text-[#0071e3] transition-colors">Security</a>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-[#424245] hover:text-[#0071e3] transition-colors hidden sm:block">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-xs !px-4 !py-1.5">Get Started</Link>
          </div>
        </div>
      </nav>

      {/* ============ HERO ============ */}
      <section className="relative pt-32 pb-24 px-6 md:pt-40 md:pb-32">
        <div className="container relative z-10 text-center">
          <Reveal type="fade">
            <div className="badge mb-6 fade-up">
              <span className="badge-dot" />
              Now live · Powered by Gmail API
            </div>
          </Reveal>

          <Reveal type="up" delay={1}>
            <h1 className="headline max-w-4xl mx-auto">
              Send email<br />
              <span className="gradient-text">that lands.</span>
            </h1>
          </Reveal>

          <Reveal type="up" delay={2}>
            <p className="subhead">
              Premium email campaigns with intelligent sender rotation, seven-layer anti-spam protection, and real-time analytics. Built for teams who value deliverability.
            </p>
          </Reveal>

          <Reveal type="up" delay={3}>
            <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
              <Link href="/login" className="btn btn-primary btn-lg">
                Start Free Trial
              </Link>
              <a href="#features" className="btn btn-ghost btn-lg">
                Watch Demo →
              </a>
            </div>
          </Reveal>

          <Reveal type="up" delay={4}>
            <div className="mt-14 flex flex-wrap items-center justify-center gap-10 text-xs text-[#86868b]">
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                No credit card
              </span>
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                OAuth 2.0 secure
              </span>
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                Cancel anytime
              </span>
            </div>
          </Reveal>
        </div>

        {/* Dashboard preview with cinematic reveal + parallax */}
        <div className="container relative mt-20 md:mt-28">
          <Reveal type="blur" delay={5}>
            <Parallax speed={0.08}>
              <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-black/[0.08] border border-black/[0.06] !rounded-3xl">
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
                <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
                  {[
                    { l: 'SENT', v: '12,847', c: '#0071e3' },
                    { l: 'DELIVERED', v: '12,412', c: '#30d158' },
                    { l: 'PENDING', v: '435', c: '#ff9f0a' },
                    { l: 'FAILED', v: '12', c: '#ff3b30' },
                  ].map(s => (
                    <div key={s.l} className="bg-white border border-black/[0.06] rounded-2xl p-5">
                      <div className="text-[10px] tracking-[0.12em] text-[#86868b] font-medium">{s.l}</div>
                      <div className="text-3xl font-semibold mt-2 tracking-tight" style={{ color: s.c }}>{s.v}</div>
                    </div>
                  ))}
                </div>
                <div className="px-8 pb-8">
                  <div className="h-1.5 w-full bg-black/[0.05] rounded-full overflow-hidden">
                    <div className="h-full w-[96%] bg-[#0071e3] rounded-full transition-all duration-1000" />
                  </div>
                  <div className="flex justify-between text-xs text-[#86868b] mt-3">
                    <span>Campaign progress</span>
                    <span className="text-[#1d1d1f] font-medium">96.4%</span>
                  </div>
                </div>
              </div>
            </Parallax>
          </Reveal>
        </div>
      </section>

      {/* ============ FEATURES ============ */}
      <section id="features" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Features</div>
              <h2 className="headline-sm">
                Built with real infrastructure.<br />
                <span className="text-[#86868b]">Not templates.</span>
              </h2>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              {
                title: 'OAuth 2.0 Only',
                desc: 'Your Gmail password never touches our servers. Tokens encrypted with AES-256-GCM at rest.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                ),
              },
              {
                title: 'Real-time Dashboard',
                desc: 'Live counters streamed via Server-Sent Events. Pause, resume, or stop any campaign instantly.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                ),
              },
              {
                title: 'Smart Import',
                desc: 'Excel, CSV, and Google Sheets supported. Auto-validate, deduplicate, and filter disposables.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2" />
                  </svg>
                ),
              },
              {
                title: 'HTML Email Editor',
                desc: 'Paste your HTML. Live desktop + mobile preview. Automatic plain-text fallback for every message.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                  </svg>
                ),
              },
              {
                title: '7-Layer Anti-Spam',
                desc: 'Content spam checker, warm-up schedules, bounce handler, list hygiene, and rate guard.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                ),
              },
              {
                title: 'Sender Rotation',
                desc: 'Round-robin across 25+ Gmail accounts with per-sender batch limits and reputation tracking.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                ),
              },
            ].map((f, i) => (
              <Reveal key={f.title} type="up" delay={((i % 3) + 1) as any}>
                <div className="tilt card card-hover h-full">
                  <div className="w-12 h-12 rounded-2xl bg-[#0071e3]/10 text-[#0071e3] flex items-center justify-center mb-5">
                    {f.icon}
                  </div>
                  <h3 className="text-lg font-semibold text-[#1d1d1f] mb-2">{f.title}</h3>
                  <p className="text-sm text-[#6e6e73] leading-relaxed">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ============ WORKFLOW (sticky scroll) ============ */}
      <section id="workflow" className="section bg-gradient-to-b from-transparent via-[#f5f5f7] to-transparent">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Workflow</div>
              <h2 className="headline-sm">
                Three steps. Zero friction.
              </h2>
              <p className="subhead !text-base">
                From import to inbox in under two minutes.
              </p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { n: '01', title: 'Import', desc: 'Upload Excel, CSV, or connect Google Sheets. Validation happens automatically.' },
              { n: '02', title: 'Compose', desc: 'Paste your HTML. Preview on desktop and mobile. Send a test in one click.' },
              { n: '03', title: 'Launch', desc: 'Hit start. Watch live counters. Pause, resume, or stop anytime.' },
            ].map((s, i) => (
              <Reveal key={s.n} type="up" delay={((i % 3) + 1) as any}>
                <div className="card card-hover">
                  <div className="text-5xl font-semibold tracking-tighter text-[#0071e3]/30 mb-3">{s.n}</div>
                  <h3 className="text-xl font-semibold text-[#1d1d1f] mb-3">{s.title}</h3>
                  <p className="text-sm text-[#6e6e73] leading-relaxed">{s.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ============ SECURITY ============ */}
      <section id="security" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="card !p-12 md:!p-16 !rounded-3xl bg-gradient-to-br from-[#0071e3] to-[#5e5ce6] text-white border-0 shadow-2xl shadow-[#0071e3]/20">
              <div className="max-w-2xl">
                <div className="eyebrow !text-white/70">Security</div>
                <h2 className="headline-sm !text-white mb-6">
                  Your data. Your senders.<br />
                  Your control.
                </h2>
                <p className="text-white/80 text-lg leading-relaxed mb-8 max-w-lg">
                  Tokens encrypted with AES-256-GCM. Sessions signed with HMAC-SHA256. Login rate-limited. Every action audited.
                </p>
                <div className="grid sm:grid-cols-2 gap-4">
                  {[
                    'AES-256-GCM encryption',
                    'HMAC-signed sessions',
                    'Login rate limiting',
                    'Full audit trail',
                    'OAuth 2.0 only',
                    'No password storage',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3">
                      <svg className="w-5 h-5 text-white/80 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      </svg>
                      <span className="text-sm text-white/90">{f}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ============ CTA ============ */}
      <section className="section text-center">
        <div className="container">
          <Reveal type="up">
            <h2 className="headline max-w-3xl mx-auto">
              Ready to <span className="gradient-text">launch?</span>
            </h2>
          </Reveal>
          <Reveal type="up" delay={1}>
            <p className="subhead mb-10">
              Invite-only access. Connect your Gmail. Start sending today.
            </p>
          </Reveal>
          <Reveal type="up" delay={2}>
            <Link href="/login" className="btn btn-primary btn-lg">
              Get Started →
            </Link>
          </Reveal>
        </div>
      </section>

      {/* ============ FOOTER ============ */}
      <footer className="border-t border-black/[0.06] py-12 bg-white/40 backdrop-blur">
        <div className="container">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-6 h-6 rounded-md bg-[#0071e3]" />
              <span className="text-xs text-[#86868b]">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-7 text-xs text-[#86868b]">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-[#1d1d1f] transition-colors" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-[#1d1d1f] transition-colors">Privacy</Link>
              <Link href="/terms" className="hover:text-[#1d1d1f] transition-colors">Terms</Link>
              <Link href="/refund" className="hover:text-[#1d1d1f] transition-colors">Refund</Link>
              <Link href="/login" className="hover:text-[#1d1d1f] transition-colors">Sign in</Link>
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

# ---------- 6. Premium Login Page ----------
echo ""
echo "🔐 [5/6] Premium login page..."

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
EOF
sed -i 's/\r$//' app/login/page.tsx
echo "   ✅"

# ---------- 7. Git push ----------
echo ""
echo "🌿 [6/6] Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "UI: Apple-inspired premium redesign (blue/slate palette + scroll reveals)"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ APPLE-INSPIRED PREMIUM REDESIGN COMPLETE"
echo "==================================================="
echo ""
echo "🎨 DESIGN CHANGES:"
echo ""
echo "   🎨 PALETTE (no pink):"
echo "      Primary:    #0071e3 (Apple blue)"
echo "      Indigo:     #5e5ce6 (deep accent)"
echo "      Emerald:    #30d158 (success)"
echo "      Background: #fbfbfd (soft white)"
echo "      Text:       #1d1d1f (near-black)"
echo "      Muted:      #86868b (subtle gray)"
echo ""
echo "   ✨ MOTION (Apple cubic-bezier):"
echo "      • Scroll-triggered reveals (up/fade/left/right/scale/blur)"
echo "      • Staggered delays (100ms-600ms)"
echo "      • Slow parallax layers"
echo "      • Cinematic scale + blur reveal"
echo "      • Floating elements (6-9s loops)"
echo "      • Subtle 3D tilt on hover (1.5deg)"
echo "      • Glass morphism nav + cards"
echo "      • Shimmer highlight sweeps"
echo "      • Reduced-motion safe"
echo ""
echo "   🎯 COMPONENTS:"
echo "      ✅ components/reveal.tsx   — IntersectionObserver wrapper"
echo "      ✅ components/parallax.tsx — RequestAnimationFrame scroll"
echo ""
echo "   📄 PAGES REDESIGNED:"
echo "      ✅ /           — Cinematic hero + features grid + CTA"
echo "      ✅ /login      — Premium glass card + 'Created by DIPEN ZALA'"
echo ""
echo "==================================================="
echo ""
echo "📸 VERIFY after deploy (2-3 min):"
echo ""
echo "   https://emailcampaign-ten.vercel.app/"
echo "   https://emailcampaign-ten.vercel.app/login"
echo ""
echo "   ✨ SCROLL karo → sections fade-in hote dikhenge"
echo "   ✨ HOVER karo cards pe → 3D tilt"
echo "   ✨ BUTTON press karo → spring scale"
echo ""
echo "==================================================="
echo ""
echo "🎁 ADVANCED FEATURES TO ADD NEXT:"
echo ""
echo "   📧 EMAIL MARKETING:"
echo "   ├─ A/B subject testing"
echo "   ├─ Send-time optimization"
echo "   ├─ Open/click tracking"
echo "   └─ Attachment support"
echo ""
echo "   💳 MONETIZATION (sale ke liye must):"
echo "   ├─ Razorpay / Stripe integration"
echo "   ├─ /pricing page (3-tier)"
echo "   ├─ Subscription management"
echo "   └─ Usage-based billing"
echo ""
echo "   🎬 MORE PREMIUM UI:"
echo "   ├─ Lottie animations (After Effects exports)"
echo "   ├─ Video hero background"
echo "   ├─ 3D product mockups (Spline)"
echo "   └─ Page transitions (framer-motion)"
echo ""
echo "Bolo 'payment integration karo' — sale-ready bana dunga"
echo "==================================================="