'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';

const LABELS: Record<string, string> = {
  dashboard: 'Dashboard',
  live: 'Live',
  senders: 'Senders',
  rotation: 'Rotation',
  'anti-spam': 'Anti-Spam',
  history: 'Campaigns',
  campaigns: 'Campaigns',
  new: 'New',
  worker: 'Worker',
  settings: 'Settings',
  help: 'Help',
};

export default function Topbar({ onMenuClick }: { onMenuClick?: () => void }) {
  const path = usePathname();
  const router = useRouter();
  const [showShortcuts, setShowShortcuts] = useState(false);

  const segments = path.split('/').filter(Boolean);

  const goBack = () => {
    if (typeof window !== 'undefined' && window.history.length > 1) {
      router.back();
    } else {
      router.push('/dashboard/live');
    }
  };

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'h') {
        e.preventDefault();
        router.push('/dashboard/live');
      }
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
        e.preventDefault();
        goBack();
      }
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        router.push('/campaigns/new');
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [router]);

  return (
    <>
      <header className="topbar">
        {/* Mobile hamburger */}
        <button className="topbar-hamburger" onClick={onMenuClick} aria-label="Menu">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>

        <button className="topbar-back" onClick={goBack} title="Back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>

        <Link href="/dashboard/live" className="topbar-home" title="Home">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
        </Link>

        <nav className="topbar-breadcrumbs">
          <Link href="/dashboard/live">Home</Link>
          {segments.map((seg, i) => {
            const isLast = i === segments.length - 1;
            const label = LABELS[seg] || seg;
            return (
              <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <span className="sep">/</span>
                {isLast ? (
                  <span className="current">{label}</span>
                ) : (
                  <Link href={'/' + segments.slice(0, i + 1).join('/')}>{label}</Link>
                )}
              </span>
            );
          })}
        </nav>

        <div className="topbar-actions">
          <Link href="/campaigns/new" className="topbar-action" title="New Campaign">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </Link>
          <button className="topbar-action" onClick={() => setShowShortcuts(true)} title="Shortcuts">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <circle cx="12" cy="12" r="10" />
              <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
              <line x1="12" y1="17" x2="12.01" y2="17" />
            </svg>
          </button>
          <Link href="/settings" className="topbar-user" title="Settings">
            <div className="topbar-avatar">D</div>
          </Link>
        </div>
      </header>

      {showShortcuts && (
        <div
          onClick={() => setShowShortcuts(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
        >
          <div onClick={e => e.stopPropagation()} className="card" style={{ maxWidth: 460, width: '100%' }}>
            <h2 style={{ marginBottom: 16, fontSize: 18, fontWeight: 600 }}>⌨️ Shortcuts</h2>
            {[
              ['Ctrl + H', 'Home'],
              ['Ctrl + B', 'Back'],
              ['Ctrl + K', 'New Campaign'],
            ].map(([k, d]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <code style={{ background: 'rgba(255,255,255,0.08)', padding: '4px 12px', borderRadius: 6, fontSize: 12, color: '#e9d5ff' }}>{k}</code>
                <span style={{ color: '#cbd5e1', fontSize: 13 }}>{d}</span>
              </div>
            ))}
            <button className="btn btn-primary" onClick={() => setShowShortcuts(false)} style={{ marginTop: 16, width: '100%' }}>Got it</button>
          </div>
        </div>
      )}
    </>
  );
}
