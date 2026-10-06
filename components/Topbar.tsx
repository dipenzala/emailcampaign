'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import WorkerToggle from './WorkerToggle';
import { useEffect, useState } from 'react';

const LABELS: Record<string, string> = {
  dashboard: 'Dashboard', live: 'Live', senders: 'Senders',
  rotation: 'Rotation', 'anti-spam': 'Anti-Spam', inbox: 'Inbox',
  history: 'History', campaigns: 'Campaigns', new: 'New',
  settings: 'Settings', help: 'Help',
};

export default function Topbar({ onMenuClick }: { onMenuClick?: () => void }) {
  const path = usePathname();
  const router = useRouter();
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth <= 900);
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, []);

  const segments = path.split('/').filter(Boolean);

  const goBack = () => {
    if (window.history.length > 1) router.back();
    else router.push('/dashboard/live');
  };

  const btnStyle: React.CSSProperties = {
    width: 40, height: 40, borderRadius: 10,
    background: 'rgba(255,255,255,0.05)',
    border: '1px solid rgba(255,255,255,0.08)',
    color: '#cbd5e1',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    cursor: 'pointer', flexShrink: 0, textDecoration: 'none',
    transition: 'all .2s',
  };

  return (
    <header
      style={{
        position: 'fixed',
        top: 0, left: 0, right: 0,
        zIndex: 100,
        background: 'rgba(5,6,10,0.95)',
        backdropFilter: 'saturate(180%) blur(24px)',
        WebkitBackdropFilter: 'saturate(180%) blur(24px)',
        borderBottom: '1px solid rgba(255,255,255,0.08)',
        padding: isMobile ? '10px 14px' : '12px 24px',
        display: 'flex',
        alignItems: 'center',
        gap: isMobile ? 8 : 10,
        minHeight: isMobile ? 60 : 64,
      }}
    >
      {/* Hamburger — mobile only */}
      {isMobile && (
        <button
          onClick={onMenuClick}
          style={{
            ...btnStyle,
            background: 'linear-gradient(135deg, rgba(139,92,246,0.25), rgba(236,72,153,0.18))',
            border: '1px solid rgba(139,92,246,0.35)',
            color: '#e9d5ff',
          }}
          aria-label="Menu"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
      )}

      {/* Back */}
      <button onClick={goBack} style={btnStyle} title="Back">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="15 18 9 12 15 6" />
        </svg>
      </button>

      {/* Home */}
      <Link href="/dashboard/live" style={btnStyle} title="Home">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
          <polyline points="9 22 9 12 15 12 15 22" />
        </svg>
      </Link>

      {/* Breadcrumbs — desktop only */}
      {!isMobile && (
        <nav style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: '#64748b', flex: 1, minWidth: 0, overflow: 'hidden', padding: '0 8px' }}>
          <Link href="/dashboard/live" style={{ color: '#94a3b8', textDecoration: 'none' }}>Home</Link>
          {segments.map((s, i) => {
            const last = i === segments.length - 1;
            const label = LABELS[s] || s;
            return (
              <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                <span style={{ color: '#334155' }}>/</span>
                {last ? (
                  <span style={{ color: '#fff', fontWeight: 500 }}>{label}</span>
                ) : (
                  <Link href={'/' + segments.slice(0, i + 1).join('/')} style={{ color: '#94a3b8', textDecoration: 'none' }}>{label}</Link>
                )}
              </span>
            );
          })}
        </nav>
      )}

      {/* Spacer on mobile */}
      {isMobile && <div style={{ flex: 1 }} />}

      {/* Actions */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        <Link href="/campaigns/new" style={btnStyle} title="New Campaign">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </Link>
        <Link
          href="/settings"
          style={{
            width: 40, height: 40, borderRadius: 10,
            background: 'linear-gradient(135deg, #8b5cf6, #ec4899)',
            color: '#fff',
            fontWeight: 700,
            fontSize: 14,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            textDecoration: 'none',
            flexShrink: 0,
          }}
          title="Settings"
        >
          D
        </Link>
      </div>
    </header>
  );
}
