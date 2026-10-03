'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';

const LABELS: Record<string, string> = {
  dashboard: 'Dashboard', live: 'Live', senders: 'Senders',
  rotation: 'Rotation', 'anti-spam': 'Anti-Spam',
  history: 'History', campaigns: 'Campaigns', new: 'New',
  worker: 'Worker', settings: 'Settings', help: 'Help',
};

export default function Topbar({ onMenuClick }: { onMenuClick?: () => void }) {
  const path = usePathname();
  const router = useRouter();
  const [shortcuts, setShortcuts] = useState(false);

  const segments = path.split('/').filter(Boolean);

  const goBack = () => {
    if (typeof window !== 'undefined' && window.history.length > 1) router.back();
    else router.push('/dashboard/live');
  };

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'h') { e.preventDefault(); router.push('/dashboard/live'); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') { e.preventDefault(); goBack(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); router.push('/campaigns/new'); }
      if (e.key === 'Escape') setShortcuts(false);
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [router]);

  return (
    <>
      <header className="topbar">
        <button className="topbar-menu-btn" onClick={onMenuClick} aria-label="Menu">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>

        <button className="topbar-btn" onClick={goBack} title="Back (Ctrl+B)">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>

        <Link href="/dashboard/live" className="topbar-btn" title="Home (Ctrl+H)">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
        </Link>

        <nav className="topbar-breadcrumbs">
          <Link href="/dashboard/live">Home</Link>
          {segments.map((s, i) => {
            const last = i === segments.length - 1;
            const label = LABELS[s] || s;
            return (
              <span key={i} className="topbar-crumb">
                <span className="sep">/</span>
                {last ? <span className="current">{label}</span> : <Link href={'/' + segments.slice(0, i + 1).join('/')}>{label}</Link>}
              </span>
            );
          })}
        </nav>

        <div className="topbar-actions">
          <Link href="/campaigns/new" className="topbar-btn" title="New Campaign (Ctrl+K)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </Link>
          <button className="topbar-btn" onClick={() => setShortcuts(true)} title="Shortcuts">⌘</button>
          <Link href="/settings" className="topbar-avatar" title="Settings">D</Link>
        </div>
      </header>

      {shortcuts && (
        <div className="modal-backdrop" onClick={() => setShortcuts(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <h2 style={{ marginBottom: 16, fontSize: 20, fontWeight: 600 }}>⌨️ Shortcuts</h2>
            {[['Ctrl + H', 'Home'], ['Ctrl + B', 'Back'], ['Ctrl + K', 'New Campaign'], ['Esc', 'Close']].map(([k, d]) => (
              <div key={k} className="shortcut-row">
                <code>{k}</code><span>{d}</span>
              </div>
            ))}
            <button className="btn btn-primary" style={{ width: '100%', marginTop: 20 }} onClick={() => setShortcuts(false)}>Got it</button>
          </div>
        </div>
      )}
    </>
  );
}
