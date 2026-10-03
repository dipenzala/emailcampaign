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
