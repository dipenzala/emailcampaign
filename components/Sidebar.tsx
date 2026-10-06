'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

const NAV_SECTIONS = [
  {
    section: 'Dashboard',
    items: [
      { href: '/dashboard/live', label: 'Live Dashboard', icon: '📊' },
      { href: '/campaigns/new', label: 'New Campaign', icon: '✉️' },
      { href: '/history', label: 'Campaign History', icon: '📜' },
    ],
  },
  {
    section: 'Senders',
    items: [
      { href: '/senders', label: 'Manage Senders', icon: '🔐' },
      { href: '/senders/rotation', label: 'Rotation', icon: '🔄' },
    ],
  },
  {
    section: 'Protection',
    items: [
      { href: '/anti-spam', label: 'Spam Checker', icon: '🛡️' },
    ],
  },
  {
    section: 'System',
    items: [
      { href: '/worker', label: 'Worker', icon: '🤖' },
      { href: '/bulk', label: 'Bulk Sender', icon: '📧' },
      { href: '/control', label: 'Worker Control', icon: '🎛️' },
      { href: '/settings', label: 'Settings', icon: '⚙️' },
      { href: '/help', label: 'Help', icon: '💡' },
    ],
  },
];

export default function Sidebar({ mobileOpen, setMobileOpen }: { mobileOpen: boolean; setMobileOpen: (v: boolean) => void }) {
  const path = usePathname();
  const router = useRouter();

  const logout = async () => {
    await fetch('/api/auth/simple-logout', { method: 'POST' });
    router.push('/login');
    router.refresh();
  };

  return (
    <>
      {mobileOpen && <div className="sidebar-backdrop" onClick={() => setMobileOpen(false)} />}

      <aside className={`sidebar ${mobileOpen ? 'mobile-open' : ''}`}>
        <div className="sidebar-header">
          <Link href="/dashboard/live" className="sidebar-brand" onClick={() => setMobileOpen(false)}>
            <div className="sidebar-logo-mark" />
            <div className="sidebar-brand-text">
              <div className="sidebar-brand-title">EmailCampaign</div>
              <div className="sidebar-brand-sub">Premium</div>
            </div>
          </Link>
          <button className="sidebar-close-mobile" onClick={() => setMobileOpen(false)}>✕</button>
        </div>

        <nav className="sidebar-nav">
          {NAV_SECTIONS.map(group => (
            <div key={group.section} className="sidebar-group">
              <div className="sidebar-section">{group.section}</div>
              {group.items.map(item => {
                const active = path === item.href || path.startsWith(item.href + '/');
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`sidebar-link ${active ? 'active' : ''}`}
                    onClick={() => setMobileOpen(false)}
                  >
                    <span className="sidebar-link-icon">{item.icon}</span>
                    <span className="sidebar-link-text">{item.label}</span>
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button className="sidebar-logout" onClick={logout}>
            <span className="sidebar-logout-icon">🚪</span>
            <span>Logout</span>
          </button>
        </div>
      </aside>
    </>
  );
}
