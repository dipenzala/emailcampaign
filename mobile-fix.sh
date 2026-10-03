#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 📱 MOBILE RESPONSIVE FIX"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. FIX APP SHELL — Mobile hamburger always visible
# ==========================================
echo "📱 [1/9] Fixing AppShell..."

mkdir -p components

cat > components/AppShell.tsx <<'EOF'
'use client';
import { usePathname } from 'next/navigation';
import { useState, useEffect } from 'react';
import Sidebar from './Sidebar';
import Topbar from './Topbar';

const PUBLIC_ROUTES = ['/', '/login'];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const path = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  const isPublic = PUBLIC_ROUTES.includes(path);

  // Auto-close on route change
  useEffect(() => { setMobileOpen(false); }, [path]);

  // Lock body scroll when sidebar open on mobile
  useEffect(() => {
    if (typeof document === 'undefined') return;
    if (mobileOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => { document.body.style.overflow = ''; };
  }, [mobileOpen]);

  if (isPublic) return <>{children}</>;

  return (
    <div className="app-shell">
      <Sidebar mobileOpen={mobileOpen} setMobileOpen={setMobileOpen} />
      <div className="app-main">
        <Topbar onMenuClick={() => setMobileOpen(true)} />
        <div className="app-content">{children}</div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' components/AppShell.tsx
echo "   ✅"

# ==========================================
# 2. FIX SIDEBAR
# ==========================================
echo "📱 [2/9] Fixing Sidebar..."

cat > components/Sidebar.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' components/Sidebar.tsx
echo "   ✅"

# ==========================================
# 3. FIX TOPBAR
# ==========================================
echo "📱 [3/9] Fixing Topbar..."

cat > components/Topbar.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' components/Topbar.tsx
echo "   ✅"

# ==========================================
# 4. MOBILE RESPONSIVE CSS (full rewrite)
# ==========================================
echo "📱 [4/9] Rewriting globals.css for mobile..."

cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root{
  --bg:#05060a;
  --fg:#f5f7fa;
  --accent:#a78bfa;
  --glass:rgba(15,17,25,0.6);
  --border:rgba(255,255,255,0.08);
  --sidebar-w:260px;
}

*{ -webkit-tap-highlight-color:transparent; box-sizing:border-box; }

html,body{
  background:var(--bg);
  color:var(--fg);
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",Inter,sans-serif;
  -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
  margin:0;
  padding:0;
}

/* ============ APP SHELL ============ */
.app-shell{
  display:block;
  min-height:100vh;
  position:relative;
}
.app-shell::before{
  content:'';
  position:fixed;
  inset:0;
  background:
    radial-gradient(ellipse 80% 60% at 20% 10%, rgba(139,92,246,0.15), transparent 60%),
    radial-gradient(ellipse 60% 50% at 80% 90%, rgba(236,72,153,0.12), transparent 60%);
  pointer-events:none;
  z-index:0;
}
.app-main{
  min-height:100vh;
  position:relative;
  z-index:1;
  padding-left:var(--sidebar-w);
  transition:padding-left .3s cubic-bezier(.22,1,.36,1);
}
.app-content{
  padding:24px;
  max-width:1400px;
  margin:0 auto;
  width:100%;
}

/* ============ SIDEBAR ============ */
.sidebar{
  position:fixed;
  top:0; left:0; bottom:0;
  width:var(--sidebar-w);
  background:linear-gradient(180deg, rgba(15,17,25,0.98) 0%, rgba(10,12,20,0.98) 100%);
  backdrop-filter:blur(20px);
  border-right:1px solid var(--border);
  display:flex;
  flex-direction:column;
  z-index:200;
  transition:transform .3s cubic-bezier(.22,1,.36,1);
}
.sidebar-backdrop{
  position:fixed;
  inset:0;
  background:rgba(0,0,0,0.7);
  backdrop-filter:blur(4px);
  z-index:150;
  animation:fadeIn .2s ease;
}
.sidebar-logo{
  padding:18px 20px;
  display:flex;
  align-items:center;
  gap:12px;
  border-bottom:1px solid var(--border);
  min-height:64px;
}
.sidebar-logo-mark{
  width:36px;height:36px;
  border-radius:12px;
  background:linear-gradient(135deg,#8b5cf6 0%,#ec4899 100%);
  flex-shrink:0;
  box-shadow:0 8px 24px rgba(139,92,246,0.4);
}
.sidebar-logo-text{
  font-weight:600;
  font-size:14px;
  letter-spacing:-0.01em;
  white-space:nowrap;
  flex:1;
}
.sidebar-close-mobile{
  display:none;
  background:rgba(255,255,255,0.06);
  border:1px solid var(--border);
  color:#fff;
  width:32px;
  height:32px;
  border-radius:8px;
  cursor:pointer;
  font-size:16px;
  align-items:center;
  justify-content:center;
}
.sidebar-nav{
  flex:1;
  padding:12px;
  overflow-y:auto;
  overflow-x:hidden;
}
.sidebar-section{
  font-size:10px;
  text-transform:uppercase;
  letter-spacing:0.1em;
  color:#64748b;
  padding:14px 12px 6px;
  white-space:nowrap;
}
.sidebar-link{
  display:flex;
  align-items:center;
  gap:12px;
  padding:11px 12px;
  border-radius:12px;
  color:#cbd5e1;
  text-decoration:none;
  font-size:14px;
  margin-bottom:2px;
  transition:all .2s cubic-bezier(.22,1,.36,1);
  position:relative;
  white-space:nowrap;
}
.sidebar-link:hover{
  background:rgba(255,255,255,0.05);
  color:#fff;
}
.sidebar-link.active{
  background:linear-gradient(135deg, rgba(139,92,246,0.25) 0%, rgba(236,72,153,0.15) 100%);
  color:#fff;
  box-shadow:0 4px 20px rgba(139,92,246,0.2);
}
.sidebar-link.active::before{
  content:'';
  position:absolute;
  left:0; top:20%; bottom:20%;
  width:3px;
  background:linear-gradient(180deg,#8b5cf6,#ec4899);
  border-radius:0 3px 3px 0;
}
.sidebar-link-icon{
  width:20px;height:20px;
  flex-shrink:0;
  display:flex;
  align-items:center;
  justify-content:center;
  font-size:16px;
}
.sidebar-footer{
  padding:12px;
  border-top:1px solid var(--border);
}
.sidebar-collapse-btn{
  display:flex;
  align-items:center;
  justify-content:center;
  gap:8px;
  padding:11px;
  width:100%;
  border-radius:10px;
  background:rgba(255,255,255,0.03);
  border:1px solid var(--border);
  color:#94a3b8;
  font-size:13px;
  cursor:pointer;
  transition:all .2s;
}
.sidebar-collapse-btn:hover{
  background:rgba(255,255,255,0.06);
  color:#fff;
}

/* ============ TOPBAR ============ */
.topbar{
  position:sticky;
  top:0;
  z-index:100;
  background:rgba(5,6,10,0.85);
  backdrop-filter:saturate(180%) blur(20px);
  -webkit-backdrop-filter:saturate(180%) blur(20px);
  border-bottom:1px solid var(--border);
  padding:10px 16px;
  display:flex;
  align-items:center;
  gap:8px;
  min-height:60px;
}
.topbar-hamburger{
  display:none;
  width:38px;height:38px;
  border-radius:10px;
  background:linear-gradient(135deg, rgba(139,92,246,0.2), rgba(236,72,153,0.15));
  border:1px solid rgba(139,92,246,0.3);
  color:#e9d5ff;
  cursor:pointer;
  align-items:center;
  justify-content:center;
  flex-shrink:0;
}
.topbar-hamburger:active{ transform:scale(.95); }
.topbar-back{
  width:36px;height:36px;
  border-radius:10px;
  background:rgba(255,255,255,0.04);
  border:1px solid var(--border);
  display:flex;
  align-items:center;
  justify-content:center;
  color:#cbd5e1;
  cursor:pointer;
  transition:all .2s;
  flex-shrink:0;
}
.topbar-back:hover{
  background:rgba(255,255,255,0.08);
  color:#fff;
}
.topbar-home{
  width:36px;height:36px;
  border-radius:10px;
  background:rgba(255,255,255,0.04);
  border:1px solid var(--border);
  display:flex;
  align-items:center;
  justify-content:center;
  color:#cbd5e1;
  cursor:pointer;
  transition:all .2s;
  flex-shrink:0;
  text-decoration:none;
}
.topbar-home:hover{
  background:rgba(255,255,255,0.08);
  color:#fff;
}
.topbar-breadcrumbs{
  display:flex;
  align-items:center;
  gap:6px;
  font-size:13px;
  color:#64748b;
  flex:1;
  min-width:0;
  overflow:hidden;
}
.topbar-breadcrumbs a{
  color:#94a3b8;
  text-decoration:none;
  white-space:nowrap;
}
.topbar-breadcrumbs a:hover{ color:#fff; }
.topbar-breadcrumbs .current{
  color:#fff;
  font-weight:500;
  white-space:nowrap;
  overflow:hidden;
  text-overflow:ellipsis;
}
.topbar-breadcrumbs .sep{ color:#334155; }
.topbar-actions{
  display:flex;
  align-items:center;
  gap:6px;
  flex-shrink:0;
}
.topbar-action{
  width:36px;height:36px;
  border-radius:10px;
  background:rgba(255,255,255,0.04);
  border:1px solid var(--border);
  display:flex;
  align-items:center;
  justify-content:center;
  color:#94a3b8;
  cursor:pointer;
  transition:all .2s;
  text-decoration:none;
}
.topbar-action:hover{
  background:rgba(255,255,255,0.08);
  color:#fff;
}
.topbar-user{
  width:36px;height:36px;
  border-radius:10px;
  background:linear-gradient(135deg,#8b5cf6,#ec4899);
  border:none;
  color:#fff;
  font-weight:700;
  display:flex;
  align-items:center;
  justify-content:center;
  text-decoration:none;
  flex-shrink:0;
  font-size:13px;
}

/* ============ CARDS ============ */
.card{
  background:linear-gradient(135deg, rgba(20,22,32,0.7) 0%, rgba(15,17,25,0.7) 100%);
  backdrop-filter:blur(20px);
  border:1px solid rgba(255,255,255,0.06);
  border-radius:20px;
  padding:24px;
  position:relative;
  overflow:hidden;
  transition:all .4s cubic-bezier(.22,1,.36,1);
}
.card:hover{
  border-color:rgba(139,92,246,0.25);
  box-shadow:0 24px 60px -20px rgba(139,92,246,0.3);
}

/* ============ BUTTONS ============ */
.btn{
  display:inline-flex;
  align-items:center;
  justify-content:center;
  gap:8px;
  padding:11px 20px;
  border-radius:12px;
  font-weight:500;
  font-size:14px;
  transition:all .3s cubic-bezier(.22,1,.36,1);
  cursor:pointer;
  border:none;
  text-decoration:none;
}
.btn-primary{
  background:linear-gradient(135deg,#8b5cf6 0%,#6366f1 100%);
  color:#fff;
  box-shadow:0 8px 24px -8px rgba(139,92,246,0.5);
}
.btn-primary:active{ transform:scale(.98); }
.btn-ghost{
  background:rgba(255,255,255,0.05);
  color:#e2e8f0;
  border:1px solid rgba(255,255,255,0.1);
}
.btn-danger{
  background:linear-gradient(135deg,#ef4444,#dc2626);
  color:#fff;
}

/* ============ INPUTS ============ */
.input{
  width:100%;
  background:rgba(255,255,255,0.03);
  border:1px solid rgba(255,255,255,0.08);
  border-radius:12px;
  padding:12px 16px;
  color:#fff;
  font-size:15px;
  transition:all .2s;
  outline:none;
  font-family:inherit;
}
.input::placeholder{ color:#475569; }
.input:focus{
  border-color:rgba(139,92,246,0.5);
  background:rgba(255,255,255,0.06);
}

/* ============ ANIMATIONS ============ */
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes fadeInUp{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
.animate-in{animation:fadeInUp .6s cubic-bezier(.22,1,.36,1) both}
.animate-fade{animation:fadeIn .3s ease both}

.gradient-text{
  background:linear-gradient(120deg,#a78bfa 0%,#60a5fa 30%,#34d399 60%,#f472b6 100%);
  background-size:300% 300%;
  -webkit-background-clip:text;
  background-clip:text;
  color:transparent;
}
.aurora{position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:0}
.aurora::before,.aurora::after{
  content:'';position:absolute;width:60vw;height:60vw;border-radius:50%;
  filter:blur(120px);opacity:.35;
}
.aurora::before{background:radial-gradient(circle,#6366f1,transparent 65%);top:-20%;left:-10%}
.aurora::after{background:radial-gradient(circle,#ec4899,transparent 65%);bottom:-30%;right:-10%}
.floaty{animation:floaty 6s ease-in-out infinite}
@keyframes floaty{0%,100%{transform:translateY(0)}50%{transform:translateY(-12px)}}
.shimmer{position:relative;overflow:hidden}
.shimmer::after{
  content:'';position:absolute;inset:0;
  background:linear-gradient(115deg,transparent 30%,rgba(255,255,255,0.35) 50%,transparent 70%);
  transform:translateX(-100%);animation:shimmer 3s ease-in-out infinite;
}
@keyframes shimmer{0%{transform:translateX(-100%)}60%,100%{transform:translateX(100%)}}

/* ============ TOAST ============ */
.toast-container{
  position:fixed;
  top:80px;right:20px;
  z-index:9999;
  display:flex;
  flex-direction:column;
  gap:10px;
  pointer-events:none;
}
.toast{
  background:linear-gradient(135deg, rgba(20,22,32,0.98), rgba(15,17,25,0.98));
  border:1px solid rgba(139,92,246,0.3);
  border-radius:14px;
  padding:14px 18px;
  color:#fff;
  font-size:13px;
  box-shadow:0 20px 60px -20px rgba(0,0,0,0.8);
  pointer-events:all;
  animation:toastIn .3s cubic-bezier(.22,1,.36,1) both;
  max-width:360px;
  display:flex;
  align-items:center;
  gap:10px;
}
@keyframes toastIn{from{opacity:0;transform:translateX(100%)}to{opacity:1;transform:translateX(0)}}

/* ============ SCROLLBAR ============ */
::-webkit-scrollbar{width:8px;height:8px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:rgba(255,255,255,.1);border-radius:8px}

/* ============ MOBILE ============ */
@media(max-width:900px){
  .app-main{ padding-left:0; }
  .app-content{ padding:16px; }
  .sidebar{ transform:translateX(-100%); }
  .sidebar.mobile-open{ transform:translateX(0); }
  .sidebar-close-mobile{ display:flex; }
  .topbar-hamburger{ display:flex; }
  .topbar-breadcrumbs{ display:none; }
  .card{ border-radius:16px; padding:16px; }
  .card:hover{ transform:none; box-shadow:none; }
  .btn{ padding:10px 16px; font-size:13px; }
  .input{ padding:11px 14px; font-size:14px; }
  h1{ font-size:1.5rem !important; }
}

@media(max-width:480px){
  .app-content{ padding:12px; }
  .topbar{ padding:8px 12px; min-height:56px; gap:6px; }
  .topbar-back,.topbar-home,.topbar-action,.topbar-user,.topbar-hamburger{ width:34px; height:34px; }
  .card{ padding:14px; border-radius:14px; }
  .toast-container{ right:8px; top:64px; left:8px; }
  .toast{ max-width:100%; font-size:12px; padding:12px 14px; }
}

/* ============ MOBILE TABLES → CARDS ============ */
@media(max-width:768px){
  .mobile-table-wrap{ overflow-x:auto; -webkit-overflow-scrolling:touch; }
  .mobile-table-wrap table{ min-width:500px; }
  .hide-mobile{ display:none !important; }
}
@media(min-width:769px){
  .hide-desktop{ display:none !important; }
}
EOF
sed -i 's/\r$//' app/globals.css
echo "   ✅"

# ==========================================
# 5. FIX SENDERS PAGE — mobile card view
# ==========================================
echo "📱 [5/9] Rewriting senders page..."

mkdir -p app/senders

cat > app/senders/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import { toast } from '@/components/Toast';

export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const r = await fetch('/api/senders');
      const j = await r.json();
      setList(Array.isArray(j) ? j : []);
    } catch {}
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const connect = () => {
    if (!email) return;
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email);
  };

  const disconnect = async (id: string, em: string) => {
    if (!confirm(`Disconnect ${em}?`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/disconnect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      if (!r.ok) throw new Error('Failed');
      toast(`Disconnected ${em}`, 'success');
      await load();
    } catch (e: any) { toast(e.message, 'error'); }
    setBusy(false);
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>

      {/* Connect */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">Connect Gmail / Workspace</h2>
        <div className="flex flex-col sm:flex-row gap-2">
          <input
            className="input flex-1"
            placeholder="sales01@company.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
            type="email"
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email || busy}>
            Connect Google
          </button>
        </div>
        <p className="text-xs text-slate-400 mt-2">
          OAuth only. Permission: "Send email on your behalf" must be allowed.
        </p>
      </div>

      {/* Senders list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400">No senders connected</p>
        </div>
      ) : (
        <>
          {/* Desktop table */}
          <div className="hidden md:block card !p-0 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
                <tr>
                  <th className="p-3">Email</th>
                  <th className="p-3">Name</th>
                  <th className="p-3">Status</th>
                  <th className="p-3">Sent Today</th>
                  <th className="p-3">Last Success</th>
                  <th className="p-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                {list.map(s => (
                  <tr key={s.id} className="border-t border-white/5">
                    <td className="p-3">{s.email}</td>
                    <td className="p-3">{s.displayName || '—'}</td>
                    <td className="p-3">
                      <span className={s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}>
                        ● {s.status}
                      </span>
                    </td>
                    <td className="p-3">{s.sentToday}</td>
                    <td className="p-3 text-xs text-slate-500">
                      {s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}
                    </td>
                    <td className="p-3 text-right">
                      <button
                        onClick={() => disconnect(s.id, s.email)}
                        disabled={busy}
                        className="text-xs px-3 py-1.5 rounded-lg bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20 transition"
                      >
                        Disconnect
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="md:hidden space-y-3">
            {list.map(s => (
              <div key={s.id} className="card !p-4">
                <div className="flex items-start justify-between gap-2 mb-3">
                  <div className="min-w-0 flex-1">
                    <div className="text-xs text-slate-500 truncate">{s.displayName || 'No name'}</div>
                    <div className="font-medium text-sm truncate">{s.email}</div>
                  </div>
                  <span className={`text-xs flex-shrink-0 px-2 py-1 rounded-lg ${s.status === 'CONNECTED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'}`}>
                    ● {s.status}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold text-sm">{s.sentToday}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">LAST SUCCESS</div>
                    <div className="font-semibold text-xs">
                      {s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleDateString() : '—'}
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => disconnect(s.id, s.email)}
                  disabled={busy}
                  className="btn btn-danger w-full text-xs"
                >
                  Disconnect
                </button>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
EOF
sed -i 's/\r$//' app/senders/page.tsx
echo "   ✅"

# ==========================================
# 6. FIX DASHBOARD PAGE — proper redirect
# ==========================================
echo "📱 [6/9] Fixing dashboard page..."

mkdir -p app/dashboard

cat > app/dashboard/page.tsx <<'EOF'
'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function DashboardRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace('/dashboard/live');
  }, [router]);
  return (
    <div className="flex items-center justify-center min-h-[60vh] text-slate-500 text-sm">
      Redirecting to Live Dashboard…
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/page.tsx
echo "   ✅"

# ==========================================
# 7. DELETE OLD DASHBOARD LAYOUT (if exists)
# ==========================================
echo "🧹 [7/9] Removing old dashboard layout..."

rm -f app/dashboard/layout.tsx 2>/dev/null || true
rm -f app/dashboard/logout-button.tsx 2>/dev/null || true
echo "   ✅"

# ==========================================
# 8. FIX DASHBOARD LIVE PAGE — mobile
# ==========================================
echo "📱 [8/9] Fixing live dashboard for mobile..."

mkdir -p app/dashboard/live

cat > app/dashboard/live/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function LiveDashboard() {
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [tick, setTick] = useState(0);

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats);
        setSenders(j.senders || []);
        setCampaign(j.campaign);
        setActivity(j.activity || []);
        setTick(t => t + 1);
      }
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, []);

  const progress = stats.total > 0 ? ((stats.total - stats.pending) / stats.total) * 100 : 0;

  return (
    <div className="space-y-4 md:space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight flex items-center gap-2 flex-wrap">
            🔴 Live Dashboard
            <span className="text-xs px-2 py-1 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 animate-pulse">LIVE</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Auto-refresh 3s · {new Date().toLocaleTimeString()}
          </p>
        </div>
        <Link href="/campaigns/new" className="btn btn-primary text-sm">+ New Campaign</Link>
      </div>

      {/* Big KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <KPI label="TOTAL" value={stats.total} color="text-white" big />
        <KPI label="SENT" value={stats.sent} color="text-blue-400" big />
        <KPI label="PENDING" value={stats.pending} color="text-amber-400" big />
        <KPI label="FAILED" value={stats.failed} color="text-red-400" big />
      </div>

      {/* Small KPIs */}
      <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
        <KPI label="QUEUED" value={stats.queued} color="text-yellow-400" />
        <KPI label="PROCESSING" value={stats.processing} color="text-purple-400" />
        <KPI label="DELIVERED" value={stats.delivered} color="text-emerald-400" />
        <KPI label="BOUNCED" value={stats.bounced} color="text-orange-400" />
        <KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" />
      </div>

      {/* Progress */}
      <div className="card">
        <div className="flex justify-between text-sm mb-2">
          <span className="font-medium">Overall Progress</span>
          <span className="text-lg font-bold">{progress.toFixed(1)}%</span>
        </div>
        <div className="w-full h-3 bg-slate-800 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 transition-all duration-500 rounded-full"
            style={{ width: progress + '%' }}
          />
        </div>
      </div>

      {/* Senders */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">
          👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)
        </h2>
        {senders.length === 0 ? (
          <p className="text-sm text-slate-400">No senders connected</p>
        ) : (
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {senders.map((s, i) => {
              const usage = s.dailyLimit > 0 ? (s.sentToday / s.dailyLimit) * 100 : 0;
              return (
                <div key={i} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
                  <div className="text-xs text-slate-400 truncate">{s.email}</div>
                  <div className="flex items-center justify-between mt-2">
                    <span className={`text-xs ${s.status === 'CONNECTED' ? 'text-emerald-400' : 'text-red-400'}`}>
                      ● {s.status}
                    </span>
                    <span className="text-xs text-slate-500">{s.sentToday}/{s.dailyLimit}</span>
                  </div>
                  <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mt-2">
                    <div
                      className={`h-full ${usage >= 100 ? 'bg-red-500' : usage >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}`}
                      style={{ width: Math.min(100, usage) + '%' }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {campaign && (
        <div className="card">
          <h2 className="font-semibold mb-3 text-sm md:text-base flex items-center gap-2 flex-wrap">
            📧 Latest Campaign
            <span className="text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400">{campaign.status}</span>
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
            <div>
              <div className="text-xs text-slate-500">Name</div>
              <div className="font-medium truncate">{campaign.name}</div>
            </div>
            <div>
              <div className="text-xs text-slate-500">Subject</div>
              <div className="font-medium truncate">{campaign.subject}</div>
            </div>
            <div>
              <div className="text-xs text-slate-500">Created</div>
              <div className="font-medium text-xs">
                {new Date(campaign.createdAt).toLocaleString()}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Activity */}
      <div className="card">
        <h2 className="font-semibold mb-3 text-sm md:text-base">📜 Live Activity</h2>
        <div className="bg-black border border-slate-800 rounded-lg p-3 md:p-4 max-h-64 overflow-auto font-mono text-xs">
          {activity.length === 0 ? (
            <div className="text-slate-500">Waiting for activity...</div>
          ) : (
            activity.map((l, i) => <div key={i} className="text-emerald-300 py-0.5">{l}</div>)
          )}
        </div>
      </div>
    </div>
  );
}

function KPI({ label, value, color, big = false }: { label: string; value: number; color: string; big?: boolean }) {
  return (
    <div className={`${big ? 'card !p-4 md:!p-5' : 'bg-slate-950 border border-slate-800 rounded-lg p-2.5 md:p-3'}`}>
      <div className="text-[9px] md:text-[10px] uppercase text-slate-500 tracking-wider">{label}</div>
      <div className={`${big ? 'text-2xl md:text-4xl' : 'text-lg md:text-xl'} font-bold mt-1 ${color}`}>
        {(value || 0).toLocaleString()}
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/live/page.tsx
echo "   ✅"

# ==========================================
# 9. GIT PUSH
# ==========================================
echo ""
echo "🌿 [9/9] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: full mobile responsive — cards, sidebar, topbar, tables"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ MOBILE FIX DEPLOYED"
echo "==============================================="
echo ""
echo "📱 Mobile fixes:"
echo "   ✓ Sidebar slides in from left with hamburger"
echo "   ✓ Backdrop overlay with blur"
echo "   ✓ Topbar: hamburger + back + home visible"
echo "   ✓ Senders page: card layout on mobile"
echo "   ✓ Dashboard live: stacked KPIs"
echo "   ✓ Toasts: full-width on mobile"
echo "   ✓ Cards: smaller padding + radius"
echo "   ✓ No horizontal scroll"
echo "   ✓ Touch-friendly buttons (34-44px)"
echo ""
echo "🎯 2-3 min wait karo, phir mobile pe kholo:"
echo "   https://emailcampaign-ten.vercel.app/login"
echo "   Password: DIPEN@3899"
echo ""
echo "📌 Hard refresh:"
echo "   Chrome mobile: Settings → Privacy → Clear cache"
echo "   Ya Incognito mode me kholo"
echo "==============================================="