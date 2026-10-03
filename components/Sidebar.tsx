'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';

const NAV_ITEMS = [
  { section: 'Main', items: [
    { href: '/dashboard/live', label: 'Live Dashboard', icon: '🔴' },
    { href: '/campaigns/new', label: 'New Campaign', icon: '📧' },
  ]},
  { section: 'Manage', items: [
    { href: '/senders', label: 'Senders', icon: '🔐' },
    { href: '/senders/rotation', label: 'Rotation', icon: '🔄' },
    { href: '/anti-spam', label: 'Anti-Spam', icon: '🛡️' },
  ]},
  { section: 'History', items: [
    { href: '/history', label: 'Campaigns', icon: '📜' },
  ]},
  { section: 'Account', items: [
    { href: '/settings', label: 'Settings', icon: '⚙️' },
    { href: '/help', label: 'Help', icon: '❓' },
  ]},
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
      {/* Backdrop */}
      {mobileOpen && (
        <div
          className="sidebar-backdrop"
          onClick={() => setMobileOpen(false)}
        />
      )}

      <aside className={`sidebar ${mobileOpen ? 'mobile-open' : ''}`}>
        <div className="sidebar-logo">
          <div className="sidebar-logo-mark" />
          <div className="sidebar-logo-text">EmailCampaign</div>
          <button
            className="sidebar-close-mobile"
            onClick={() => setMobileOpen(false)}
            aria-label="Close menu"
          >✕</button>
        </div>

        <nav className="sidebar-nav">
          {NAV_ITEMS.map(group => (
            <div key={group.section}>
              <div className="sidebar-section">{group.section}</div>
              {group.items.map(item => {
                const active = path === item.href || (item.href !== '/dashboard' && path.startsWith(item.href + '/'));
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
          <button className="sidebar-collapse-btn" onClick={logout} style={{ color: '#fca5a5' }}>
            <span>🚪</span>
            <span>Logout</span>
          </button>
        </div>
      </aside>
    </>
  );
}
