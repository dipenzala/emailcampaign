'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';
import EmergencyStop from './EmergencyStop';

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

export default function Topbar({ sidebarCollapsed }: { sidebarCollapsed: boolean }) {
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

  const goHome = () => router.push('/dashboard/live');

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'h') { e.preventDefault(); router.push('/dashboard/live'); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') { e.preventDefault(); goBack(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); router.push('/campaigns/new'); }
      if (e.key === '?' && e.shiftKey) { setShowShortcuts(v => !v); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [router]);

  return (
    <>
      <header className="topbar">
        <button className="topbar-back" onClick={goBack} title="Back (Ctrl+B)">
          <span style={{ fontSize: 16 }}>←</span>
        </button>
        <button className="topbar-home" onClick={goHome} title="Home (Ctrl+H)">
          <span style={{ fontSize: 16 }}>⌂</span>
        </button>

        <nav className="topbar-breadcrumbs">
          <Link href="/dashboard/live">Home</Link>
          {segments.map((seg, i) => {
            const isLast = i === segments.length - 1;
            const label = LABELS[seg] || seg;
            return (
              <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span className="sep">/</span>
                {isLast ? <span className="current">{label}</span> : <Link href={'/' + segments.slice(0, i + 1).join('/')}>{label}</Link>}
              </span>
            );
          })}
        </nav>

        <div className="topbar-actions">
          <EmergencyStop />
          <Link href="/campaigns/new" className="topbar-action" title="New Campaign (Ctrl+K)">
            <span style={{ fontSize: 16 }}>+</span>
          </Link>
          <button className="topbar-action" onClick={() => setShowShortcuts(true)} title="Shortcuts (?)">
            <span style={{ fontSize: 14 }}>?</span>
          </button>
          <div className="topbar-user" onClick={() => router.push('/settings')}>
            <div className="topbar-avatar">D</div>
            <span style={{ fontSize: 13, color: '#e2e8f0' }} className="hidden md:inline">Dipen</span>
          </div>
        </div>
      </header>

      {showShortcuts && (
        <div onClick={() => setShowShortcuts(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
          <div onClick={e => e.stopPropagation()} className="card" style={{ maxWidth: 500, width: '100%' }}>
            <h2 style={{ marginBottom: 16, fontSize: 20 }}>⌨️ Keyboard Shortcuts</h2>
            {[
              ['Ctrl + H', 'Home / Live Dashboard'],
              ['Ctrl + B', 'Go Back'],
              ['Ctrl + K', 'New Campaign'],
              ['?', 'Show this dialog'],
            ].map(([key, desc]) => (
              <div key={key} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <code style={{ background: 'rgba(255,255,255,0.08)', padding: '3px 10px', borderRadius: 6, fontSize: 12, color: '#e9d5ff' }}>{key}</code>
                <span style={{ color: '#cbd5e1', fontSize: 13 }}>{desc}</span>
              </div>
            ))}
            <button className="btn btn-primary" onClick={() => setShowShortcuts(false)} style={{ marginTop: 16, width: '100%' }}>Got it</button>
          </div>
        </div>
      )}
    </>
  );
}
