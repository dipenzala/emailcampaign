#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ✨ ULTRA PREMIUM LAYOUT FIX"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. VERIFY ALL PAGES EXIST
# ==========================================
echo "📁 [1/7] Verifying all pages..."

mkdir -p app/dashboard/live app/campaigns/new app/senders app/senders/rotation \
         app/history app/anti-spam app/settings app/help app/login \
         'app/campaigns/[id]' components

for f in \
  "app/dashboard/live/page.tsx" \
  "app/campaigns/new/page.tsx" \
  "app/senders/page.tsx" \
  "app/senders/rotation/page.tsx" \
  "app/history/page.tsx" \
  "app/anti-spam/page.tsx" \
  "app/settings/page.tsx" \
  "app/help/page.tsx" \
  "app/login/page.tsx" \
  "app/dashboard/page.tsx" ; do
  if [ -f "$f" ]; then
    echo "   ✅ $f"
  else
    echo "   ⚠️  MISSING: $f — creating placeholder"
    mkdir -p "$(dirname "$f")"
    echo "'use client';
export default function Page() {
  return <div className=\"card\">This page is under construction.</div>;
}" > "$f"
  fi
done
echo ""

# ==========================================
# 2. APP SHELL — center content, better layout
# ==========================================
echo "🎯 [2/7] Rewriting AppShell..."

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

  useEffect(() => { setMobileOpen(false); }, [path]);

  useEffect(() => {
    if (typeof document === 'undefined') return;
    document.body.style.overflow = mobileOpen ? 'hidden' : '';
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
# 3. SIDEBAR — all links, proper layout
# ==========================================
echo "🎯 [3/7] Rewriting Sidebar..."

cat > components/Sidebar.tsx <<'EOF'
'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

const NAV_SECTIONS = [
  {
    section: 'Dashboard',
    items: [
      { href: '/dashboard/live', label: 'Live Dashboard', icon: '📊' },
      { href: '/campaigns/new', label: 'New Campaign', icon: '✉️' },
    ],
  },
  {
    section: 'Manage',
    items: [
      { href: '/senders', label: 'Senders', icon: '🔐' },
      { href: '/senders/rotation', label: 'Rotation', icon: '🔄' },
      { href: '/anti-spam', label: 'Anti-Spam', icon: '🛡️' },
    ],
  },
  {
    section: 'Activity',
    items: [
      { href: '/history', label: 'Campaign History', icon: '📜' },
    ],
  },
  {
    section: 'System',
    items: [
      { href: '/settings', label: 'Settings', icon: '⚙️' },
      { href: '/help', label: 'Help & Guide', icon: '💡' },
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
          <button className="sidebar-close-mobile" onClick={() => setMobileOpen(false)} aria-label="Close">✕</button>
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
EOF
sed -i 's/\r$//' components/Sidebar.tsx
echo "   ✅"

# ==========================================
# 4. TOPBAR — proper toggle
# ==========================================
echo "🎯 [4/7] Rewriting Topbar..."

cat > components/Topbar.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' components/Topbar.tsx
echo "   ✅"

# ==========================================
# 5. PREMIUM CSS — centered, spacious, premium
# ==========================================
echo "🎨 [5/7] Rewriting premium globals.css..."

cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root{
  --bg:#05060a;
  --fg:#f5f7fa;
  --accent:#8b5cf6;
  --sidebar-w:280px;
  --border:rgba(255,255,255,0.06);
  --border-hover:rgba(139,92,246,0.3);
}

*{ -webkit-tap-highlight-color:transparent; box-sizing:border-box; }

html,body{
  background:var(--bg);
  color:var(--fg);
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",Inter,sans-serif;
  -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
  margin:0;padding:0;
  letter-spacing:-0.01em;
}

/* ============ APP SHELL ============ */
.app-shell{ min-height:100vh; position:relative; }
.app-shell::before{
  content:''; position:fixed; inset:0; pointer-events:none; z-index:0;
  background:
    radial-gradient(ellipse 60% 50% at 15% 5%, rgba(139,92,246,0.15), transparent 55%),
    radial-gradient(ellipse 50% 40% at 85% 95%, rgba(236,72,153,0.1), transparent 55%),
    radial-gradient(ellipse 40% 30% at 50% 50%, rgba(59,130,246,0.05), transparent 60%);
}
.app-main{
  min-height:100vh;
  position:relative;
  z-index:1;
  padding-left:var(--sidebar-w);
  transition:padding-left .3s cubic-bezier(.22,1,.36,1);
}
.app-content{
  padding:32px 40px 80px;
  max-width:1320px;
  margin:0 auto;
  width:100%;
}

@media(max-width:900px){
  .app-main{ padding-left:0; }
  .app-content{ padding:20px 16px 60px; }
}
@media(max-width:480px){
  .app-content{ padding:16px 12px 48px; }
}

/* ============ SIDEBAR ============ */
.sidebar{
  position:fixed;
  top:0;left:0;bottom:0;
  width:var(--sidebar-w);
  background:linear-gradient(180deg, rgba(15,17,25,0.98) 0%, rgba(10,12,20,0.99) 100%);
  backdrop-filter:blur(20px);
  border-right:1px solid var(--border);
  display:flex;flex-direction:column;
  z-index:200;
  transition:transform .3s cubic-bezier(.22,1,.36,1);
}
.sidebar-backdrop{
  position:fixed;inset:0;
  background:rgba(0,0,0,0.7);
  backdrop-filter:blur(4px);
  z-index:150;
  animation:fadeIn .2s;
}
.sidebar-header{
  padding:24px 20px 20px;
  display:flex;align-items:center;justify-content:space-between;
  border-bottom:1px solid var(--border);
  gap:12px;
}
.sidebar-brand{
  display:flex;align-items:center;gap:12px;
  text-decoration:none;color:inherit;
  flex:1;min-width:0;
}
.sidebar-logo-mark{
  width:40px;height:40px;border-radius:12px;
  background:linear-gradient(135deg,#8b5cf6 0%,#ec4899 100%);
  flex-shrink:0;
  box-shadow:0 8px 28px rgba(139,92,246,0.45);
  position:relative;
  overflow:hidden;
}
.sidebar-logo-mark::after{
  content:'';position:absolute;inset:0;
  background:linear-gradient(135deg, transparent 40%, rgba(255,255,255,0.35) 50%, transparent 60%);
  transform:translateX(-100%);
  animation:shine 3.5s ease-in-out infinite;
}
@keyframes shine{ 0%,100%{transform:translateX(-100%)} 50%{transform:translateX(100%)} }
.sidebar-brand-text{ min-width:0;flex:1; }
.sidebar-brand-title{
  font-weight:600;font-size:15px;
  letter-spacing:-0.02em;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
}
.sidebar-brand-sub{
  font-size:10px;color:#8b5cf6;
  text-transform:uppercase;letter-spacing:0.1em;
  font-weight:600;
}
.sidebar-close-mobile{
  display:none;
  background:rgba(255,255,255,0.06);
  border:1px solid var(--border);
  color:#fff;
  width:34px;height:34px;border-radius:10px;
  cursor:pointer;font-size:15px;
  align-items:center;justify-content:center;
  flex-shrink:0;
}
.sidebar-nav{
  flex:1;
  padding:16px 14px;
  overflow-y:auto;
  overflow-x:hidden;
}
.sidebar-group{ margin-bottom:8px; }
.sidebar-section{
  font-size:10px;text-transform:uppercase;letter-spacing:0.12em;
  color:#64748b;padding:16px 14px 8px;
  font-weight:600;
  white-space:nowrap;
}
.sidebar-link{
  display:flex;align-items:center;gap:14px;
  padding:12px 14px;
  border-radius:12px;
  color:#cbd5e1;
  text-decoration:none;
  font-size:14px;font-weight:500;
  margin-bottom:3px;
  transition:all .2s cubic-bezier(.22,1,.36,1);
  position:relative;white-space:nowrap;
}
.sidebar-link:hover{
  background:rgba(255,255,255,0.04);
  color:#fff;
  transform:translateX(2px);
}
.sidebar-link.active{
  background:linear-gradient(135deg, rgba(139,92,246,0.22) 0%, rgba(236,72,153,0.12) 100%);
  color:#fff;
  box-shadow:0 4px 20px rgba(139,92,246,0.18), inset 0 1px 0 rgba(255,255,255,0.08);
}
.sidebar-link.active::before{
  content:'';position:absolute;
  left:0;top:22%;bottom:22%;width:3px;
  background:linear-gradient(180deg,#8b5cf6,#ec4899);
  border-radius:0 3px 3px 0;
}
.sidebar-link-icon{
  width:22px;height:22px;
  display:flex;align-items:center;justify-content:center;
  font-size:16px;flex-shrink:0;
}
.sidebar-link-text{ flex:1; }
.sidebar-footer{
  padding:14px;
  border-top:1px solid var(--border);
}
.sidebar-logout{
  display:flex;align-items:center;justify-content:center;gap:10px;
  padding:12px;width:100%;
  border-radius:12px;
  background:rgba(239,68,68,0.08);
  border:1px solid rgba(239,68,68,0.2);
  color:#fca5a5;
  font-size:14px;font-weight:500;
  cursor:pointer;
  transition:all .2s;
}
.sidebar-logout:hover{
  background:rgba(239,68,68,0.15);
  color:#fff;
}
.sidebar-logout-icon{ font-size:16px; }

/* ============ TOPBAR ============ */
.topbar{
  position:sticky;top:0;z-index:100;
  background:rgba(5,6,10,0.75);
  backdrop-filter:saturate(180%) blur(20px);
  -webkit-backdrop-filter:saturate(180%) blur(20px);
  border-bottom:1px solid var(--border);
  padding:12px 24px;
  display:flex;align-items:center;gap:10px;
  min-height:64px;
}
.topbar-menu-btn{
  display:none;
  width:38px;height:38px;border-radius:10px;
  background:linear-gradient(135deg, rgba(139,92,246,0.18), rgba(236,72,153,0.12));
  border:1px solid rgba(139,92,246,0.3);
  color:#e9d5ff;cursor:pointer;
  align-items:center;justify-content:center;
  flex-shrink:0;
  transition:transform .2s;
}
.topbar-menu-btn:active{ transform:scale(.94); }
.topbar-btn{
  width:38px;height:38px;border-radius:10px;
  background:rgba(255,255,255,0.04);
  border:1px solid var(--border);
  display:flex;align-items:center;justify-content:center;
  color:#cbd5e1;cursor:pointer;
  transition:all .2s;flex-shrink:0;
  text-decoration:none;
}
.topbar-btn:hover{ background:rgba(255,255,255,0.08); color:#fff; }
.topbar-breadcrumbs{
  display:flex;align-items:center;gap:8px;
  font-size:13px;color:#64748b;
  flex:1;min-width:0;overflow:hidden;
  padding:0 8px;
}
.topbar-crumb{ display:inline-flex;align-items:center;gap:8px; }
.topbar-breadcrumbs a{ color:#94a3b8;text-decoration:none;white-space:nowrap;transition:color .15s; }
.topbar-breadcrumbs a:hover{ color:#fff; }
.topbar-breadcrumbs .current{ color:#fff;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }
.topbar-breadcrumbs .sep{ color:#334155; }
.topbar-actions{ display:flex;align-items:center;gap:8px;flex-shrink:0; }
.topbar-avatar{
  width:38px;height:38px;border-radius:10px;
  background:linear-gradient(135deg,#8b5cf6,#ec4899);
  color:#fff;font-weight:700;font-size:14px;
  display:flex;align-items:center;justify-content:center;
  text-decoration:none;flex-shrink:0;
  box-shadow:0 6px 20px rgba(139,92,246,0.35);
}

@media(max-width:900px){
  .topbar{ padding:10px 14px; min-height:60px; }
  .topbar-menu-btn{ display:flex; }
  .topbar-breadcrumbs{ display:none; }
  .sidebar{ transform:translateX(-100%); }
  .sidebar.mobile-open{ transform:translateX(0); }
  .sidebar-close-mobile{ display:flex; }
}
@media(max-width:480px){
  .topbar{ padding:8px 10px; gap:6px; min-height:56px; }
  .topbar-btn,.topbar-menu-btn,.topbar-avatar{ width:34px;height:34px; }
}

/* ============ CARDS ============ */
.card{
  background:linear-gradient(135deg, rgba(20,22,32,0.65) 0%, rgba(15,17,25,0.65) 100%);
  backdrop-filter:blur(20px);
  border:1px solid var(--border);
  border-radius:20px;
  padding:28px;
  position:relative;
  overflow:hidden;
  transition:all .4s cubic-bezier(.22,1,.36,1);
}
.card::before{
  content:'';position:absolute;inset:0;
  background:linear-gradient(135deg, rgba(139,92,246,0.04), transparent 40%);
  pointer-events:none;
}
.card:hover{
  border-color:var(--border-hover);
  box-shadow:0 24px 60px -30px rgba(139,92,246,0.4);
}
@media(max-width:768px){
  .card{ padding:18px; border-radius:16px; }
}
@media(max-width:480px){
  .card{ padding:14px; border-radius:14px; }
}

/* ============ BUTTONS ============ */
.btn{
  display:inline-flex;align-items:center;justify-content:center;gap:8px;
  padding:11px 22px;border-radius:12px;
  font-weight:500;font-size:14px;
  transition:all .3s cubic-bezier(.22,1,.36,1);
  cursor:pointer;border:none;text-decoration:none;
  letter-spacing:-0.01em;
}
.btn-primary{
  background:linear-gradient(135deg,#8b5cf6 0%,#6366f1 100%);
  color:#fff;
  box-shadow:0 8px 24px -8px rgba(139,92,246,0.55), inset 0 1px 0 rgba(255,255,255,0.15);
}
.btn-primary:hover{
  transform:translateY(-2px);
  box-shadow:0 12px 32px -8px rgba(139,92,246,0.7);
}
.btn-primary:active{ transform:translateY(0); }
.btn-ghost{
  background:rgba(255,255,255,0.05);
  color:#e2e8f0;
  border:1px solid rgba(255,255,255,0.1);
}
.btn-ghost:hover{ background:rgba(255,255,255,0.1); color:#fff; }
.btn-danger{
  background:linear-gradient(135deg,#ef4444,#dc2626);
  color:#fff;
  box-shadow:0 8px 24px -8px rgba(239,68,68,0.5);
}
.btn-danger:hover{ transform:translateY(-2px); }

/* ============ INPUTS ============ */
.input{
  width:100%;
  background:rgba(255,255,255,0.03);
  border:1px solid rgba(255,255,255,0.08);
  border-radius:12px;
  padding:12px 16px;
  color:#fff;font-size:14px;
  transition:all .2s;outline:none;
  font-family:inherit;
}
.input::placeholder{ color:#475569; }
.input:focus{
  border-color:rgba(139,92,246,0.5);
  background:rgba(255,255,255,0.05);
  box-shadow:0 0 0 4px rgba(139,92,246,0.1);
}

/* ============ TYPOGRAPHY ============ */
h1{ font-size:2rem; font-weight:600; letter-spacing:-0.03em; line-height:1.15; }
h2{ font-size:1.25rem; font-weight:600; letter-spacing:-0.02em; }
h3{ font-size:1rem; font-weight:600; letter-spacing:-0.01em; }
@media(max-width:768px){ h1{ font-size:1.5rem; } }
@media(max-width:480px){ h1{ font-size:1.35rem; } h2{ font-size:1.1rem; } }

/* ============ ANIMATIONS ============ */
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes fadeInUp{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}
.animate-in{animation:fadeInUp .5s cubic-bezier(.22,1,.36,1) both}
.animate-fade{animation:fadeIn .3s ease both}
.floaty{animation:floaty 6s ease-in-out infinite}
@keyframes floaty{0%,100%{transform:translateY(0)}50%{transform:translateY(-10px)}}

.gradient-text{
  background:linear-gradient(120deg,#a78bfa,#60a5fa,#34d399,#f472b6);
  background-size:300% 300%;
  -webkit-background-clip:text;background-clip:text;color:transparent;
  animation:gradient 8s ease infinite;
}
@keyframes gradient{0%,100%{background-position:0% 50%}50%{background-position:100% 50%}}

.aurora{position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:0}
.aurora::before,.aurora::after{
  content:'';position:absolute;width:60vw;height:60vw;border-radius:50%;
  filter:blur(120px);opacity:.3;
}
.aurora::before{background:radial-gradient(circle,#6366f1,transparent 65%);top:-20%;left:-10%;}
.aurora::after{background:radial-gradient(circle,#ec4899,transparent 65%);bottom:-30%;right:-10%;}

/* ============ MODAL ============ */
.modal-backdrop{
  position:fixed;inset:0;
  background:rgba(0,0,0,0.85);
  backdrop-filter:blur(8px);
  z-index:9999;
  display:flex;align-items:center;justify-content:center;
  padding:16px;
  animation:fadeIn .2s ease;
}
.modal-box{
  background:linear-gradient(135deg, rgba(20,22,32,0.98), rgba(15,17,25,0.98));
  border:1px solid rgba(139,92,246,0.25);
  border-radius:20px;
  padding:28px;
  max-width:520px;width:100%;
  max-height:90vh;overflow:auto;
  box-shadow:0 40px 100px -30px rgba(0,0,0,0.9);
  animation:fadeInUp .3s cubic-bezier(.22,1,.36,1);
}
.shortcut-row{
  display:flex;justify-content:space-between;align-items:center;
  padding:12px 0;border-bottom:1px solid rgba(255,255,255,0.05);
}
.shortcut-row code{
  background:rgba(255,255,255,0.08);padding:4px 12px;border-radius:6px;
  font-size:12px;color:#e9d5ff;font-family:monospace;
}
.shortcut-row span{ color:#cbd5e1;font-size:13px; }

/* ============ TOAST ============ */
.toast-container{
  position:fixed;top:80px;right:20px;z-index:9999;
  display:flex;flex-direction:column;gap:10px;pointer-events:none;
}
.toast{
  background:linear-gradient(135deg, rgba(20,22,32,0.98), rgba(15,17,25,0.98));
  border:1px solid rgba(139,92,246,0.3);
  border-radius:14px;
  padding:14px 18px;color:#fff;font-size:13px;
  box-shadow:0 20px 60px -20px rgba(0,0,0,0.8);
  pointer-events:all;
  animation:toastIn .3s cubic-bezier(.22,1,.36,1) both;
  max-width:360px;
  display:flex;align-items:center;gap:10px;
}
@keyframes toastIn{from{opacity:0;transform:translateX(100%)}to{opacity:1;transform:translateX(0)}}
@media(max-width:480px){
  .toast-container{ right:8px;left:8px;top:64px; }
  .toast{ max-width:100%;font-size:12px; }
}

/* ============ SCROLLBAR ============ */
::-webkit-scrollbar{width:8px;height:8px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:rgba(255,255,255,.08);border-radius:8px}
::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.15)}

/* ============ TITLES (page-level) ============ */
.page-title{
  display:flex;align-items:center;gap:12px;
  margin-bottom:8px;
  padding-top:8px;
}
.page-subtitle{
  color:#64748b;font-size:14px;margin-bottom:24px;
  padding-left:2px;
}
@media(max-width:768px){
  .page-title{ gap:8px; padding-top:4px; }
  .page-subtitle{ font-size:13px; margin-bottom:18px; }
}
EOF
sed -i 's/\r$//' app/globals.css
echo "   ✅"

# ==========================================
# 6. FIX LIVE DASHBOARD HEADER SPACING
# ==========================================
echo "🎯 [6/7] Fixing Live Dashboard header..."

mkdir -p app/dashboard/live

cat > app/dashboard/live/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

type DetailsType = 'campaigns' | 'sent' | 'pending' | 'queued' | 'processing' | 'failed' | 'delivered' | 'bounced' | 'suppressed';

export default function LiveDashboard() {
  const [stats, setStats] = useState<any>({ total: 0, sent: 0, delivered: 0, failed: 0, bounced: 0, suppressed: 0, pending: 0, queued: 0, processing: 0 });
  const [senders, setSenders] = useState<any[]>([]);
  const [activity, setActivity] = useState<string[]>([]);
  const [campaign, setCampaign] = useState<any>(null);
  const [modal, setModal] = useState<DetailsType | null>(null);
  const [modalData, setModalData] = useState<any>(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [modalSearch, setModalSearch] = useState('');

  const load = async () => {
    try {
      const r = await fetch('/api/live/stats');
      const j = await r.json();
      if (j.ok) {
        setStats(j.stats); setSenders(j.senders || []);
        setCampaign(j.campaign); setActivity(j.activity || []);
      }
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, []);

  const openModal = async (type: DetailsType) => {
    setModal(type); setModalData(null); setModalSearch(''); setModalLoading(true);
    try {
      const r = await fetch(`/api/live/details?type=${type}&limit=500`);
      setModalData(await r.json());
    } catch (e: any) { setModalData({ ok: false, error: e.message }); }
    setModalLoading(false);
  };

  const closeModal = () => { setModal(null); setModalData(null); setModalSearch(''); };
  const progress = stats.total > 0 ? ((stats.total - stats.pending) / stats.total) * 100 : 0;

  return (
    <div className="animate-in" style={{ paddingTop: 8 }}>
      {/* Page header — centered layout */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: 32, gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', justifyContent: 'center' }}>
          <h1 style={{ margin: 0 }}>🔴 Live Dashboard</h1>
          <span style={{
            fontSize: 11, padding: '5px 12px', borderRadius: 999,
            background: 'rgba(16,185,129,0.15)', color: '#34d399',
            border: '1px solid rgba(16,185,129,0.3)',
            fontWeight: 600, letterSpacing: '0.05em',
            animation: 'pulse 2s ease-in-out infinite'
          }}>● LIVE</span>
        </div>
        <p style={{ color: '#64748b', fontSize: 13, margin: 0 }}>
          Auto-refresh every 3s · Last update {new Date().toLocaleTimeString()}
        </p>
        <Link href="/campaigns/new" className="btn btn-primary" style={{ marginTop: 8 }}>
          + New Campaign
        </Link>
      </div>

      <div style={{ fontSize: 12, color: '#64748b', textAlign: 'center', marginBottom: 20 }}>
        💡 Kisi bhi card pe click karo → detailed list dekho
      </div>

      {/* Big KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
        <KPI label="TOTAL" value={stats.total} color="text-white" big onClick={() => openModal('campaigns')} hint="All campaigns" />
        <KPI label="SENT" value={stats.sent} color="text-blue-400" big onClick={() => openModal('sent')} hint="Who was sent" />
        <KPI label="PENDING" value={stats.pending} color="text-amber-400" big onClick={() => openModal('pending')} hint="Waiting" />
        <KPI label="FAILED" value={stats.failed} color="text-red-400" big onClick={() => openModal('failed')} hint="View failed" />
      </div>

      <div className="grid grid-cols-3 md:grid-cols-5 gap-2 mb-6">
        <KPI label="QUEUED" value={stats.queued} color="text-yellow-400" onClick={() => openModal('queued')} />
        <KPI label="PROCESSING" value={stats.processing} color="text-purple-400" onClick={() => openModal('processing')} />
        <KPI label="DELIVERED" value={stats.delivered} color="text-emerald-400" onClick={() => openModal('delivered')} />
        <KPI label="BOUNCED" value={stats.bounced} color="text-orange-400" onClick={() => openModal('bounced')} />
        <KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" onClick={() => openModal('suppressed')} />
      </div>

      {/* Progress */}
      <div className="card mb-6">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontWeight: 500, fontSize: 14 }}>Overall Progress</span>
          <span style={{ fontSize: 20, fontWeight: 700 }}>{progress.toFixed(1)}%</span>
        </div>
        <div style={{ width: '100%', height: 12, background: 'rgba(30,41,59,0.8)', borderRadius: 999, overflow: 'hidden' }}>
          <div style={{
            height: '100%', width: progress + '%',
            background: 'linear-gradient(90deg, #8b5cf6, #3b82f6, #10b981)',
            transition: 'width .5s ease', borderRadius: 999,
            boxShadow: '0 0 20px rgba(139,92,246,0.5)'
          }} />
        </div>
      </div>

      {/* Senders */}
      <div className="card mb-6">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 16, margin: 0 }}>👥 Senders ({senders.filter(s => s.status === 'CONNECTED').length} connected)</h2>
          <Link href="/senders" style={{ fontSize: 12, color: '#a78bfa', textDecoration: 'none' }}>Manage →</Link>
        </div>
        {senders.length === 0 ? (
          <p style={{ fontSize: 13, color: '#64748b', margin: 0 }}>No senders connected</p>
        ) : (
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {senders.map((s, i) => {
              const usage = s.dailyLimit > 0 ? (s.sentToday / s.dailyLimit) * 100 : 0;
              return (
                <div key={i} style={{ background: 'rgba(2,6,23,0.6)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 14 }}>
                  <div style={{ fontSize: 12, color: '#94a3b8', marginBottom: 8, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.email}</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                    <span style={{ fontSize: 11, color: s.status === 'CONNECTED' ? '#34d399' : '#f87171', fontWeight: 500 }}>● {s.status}</span>
                    <span style={{ fontSize: 11, color: '#64748b' }}>{s.sentToday}/{s.dailyLimit}</span>
                  </div>
                  <div style={{ width: '100%', height: 4, background: 'rgba(30,41,59,0.8)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{
                      height: '100%', width: Math.min(100, usage) + '%',
                      background: usage >= 100 ? '#ef4444' : usage >= 70 ? '#f59e0b' : '#10b981'
                    }} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {campaign && (
        <div className="card mb-6" style={{ cursor: 'pointer' }} onClick={() => openModal('campaigns')}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <h2 style={{ fontSize: 16, margin: 0 }}>📧 Latest Campaign</h2>
              <span style={{
                fontSize: 11, padding: '4px 10px', borderRadius: 999,
                background: 'rgba(59,130,246,0.15)', color: '#60a5fa',
                fontWeight: 600
              }}>{campaign.status}</span>
            </div>
            <span style={{ fontSize: 12, color: '#a78bfa' }}>See all →</span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>NAME</div><div style={{ fontSize: 14, fontWeight: 500 }}>{campaign.name}</div></div>
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>SUBJECT</div><div style={{ fontSize: 14, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{campaign.subject}</div></div>
            <div><div style={{ fontSize: 11, color: '#64748b', marginBottom: 4 }}>CREATED</div><div style={{ fontSize: 13 }}>{new Date(campaign.createdAt).toLocaleString()}</div></div>
          </div>
        </div>
      )}

      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ fontSize: 16, margin: 0 }}>📜 Live Activity</h2>
          <button onClick={() => openModal('sent')} style={{ fontSize: 12, color: '#a78bfa', background: 'none', border: 'none', cursor: 'pointer' }}>See all →</button>
        </div>
        <div style={{ background: '#000', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 16, maxHeight: 260, overflow: 'auto', fontFamily: 'monospace', fontSize: 12 }}>
          {activity.length === 0 ? (
            <div style={{ color: '#64748b' }}>Waiting for activity...</div>
          ) : (
            activity.map((l, i) => <div key={i} style={{ color: '#6ee7b7', padding: '3px 0' }}>{l}</div>)
          )}
        </div>
      </div>

      {modal && <Modal type={modal} data={modalData} loading={modalLoading} onClose={closeModal} search={modalSearch} setSearch={setModalSearch} />}
    </div>
  );
}

function KPI({ label, value, color, big = false, onClick, hint }: { label: string; value: number; color: string; big?: boolean; onClick?: () => void; hint?: string }) {
  return (
    <button
      onClick={onClick}
      disabled={!onClick}
      className={`${big ? 'card !p-5' : 'bg-slate-950 border border-slate-800 rounded-lg p-3'} text-left w-full transition-all ${onClick ? 'hover:scale-[1.02] hover:border-violet-500/40 cursor-pointer active:scale-[0.98]' : ''} group`}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: big ? 11 : 9, textTransform: 'uppercase', letterSpacing: '0.1em', color: '#64748b', fontWeight: 600 }}>{label}</div>
        {onClick && <span style={{ fontSize: 11, color: '#a78bfa', opacity: 0 }} className="group-hover:opacity-100">→</span>}
      </div>
      <div className={`${big ? 'text-3xl md:text-4xl' : 'text-lg md:text-xl'} font-bold mt-2 ${color}`}>{(value || 0).toLocaleString()}</div>
      {hint && <div style={{ fontSize: 10, color: '#475569', marginTop: 4 }}>{hint}</div>}
    </button>
  );
}

const MODAL_TITLES: Record<DetailsType, string> = {
  campaigns: '📧 All Campaigns',
  sent: '✅ Sent Recipients',
  pending: '⏳ Pending Recipients',
  queued: '⏸️ Queued Recipients',
  processing: '🔄 Processing Recipients',
  failed: '❌ Failed Recipients',
  delivered: '📬 Delivered Recipients',
  bounced: '↩️ Bounced Recipients',
  suppressed: '🚫 Suppressed Recipients',
};

function Modal({ type, data, loading, onClose, search, setSearch }: any) {
  const items: any[] = data?.items || [];
  const filtered = search
    ? items.filter((it: any) =>
        (it.email || '').toLowerCase().includes(search.toLowerCase()) ||
        (it.name || '').toLowerCase().includes(search.toLowerCase()) ||
        (it.subject || '').toLowerCase().includes(search.toLowerCase()))
    : items;

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-box" style={{ maxWidth: 900 }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, gap: 12, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>{MODAL_TITLES[type as DetailsType]}</h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {!loading && <span style={{ fontSize: 12, color: '#64748b' }}>{filtered.length} items</span>}
            <button onClick={onClose} className="btn btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }}>✕</button>
          </div>
        </div>

        <input className="input" style={{ fontSize: 13, marginBottom: 16 }} placeholder="🔍 Search..." value={search} onChange={e => setSearch(e.target.value)} />

        <div style={{ maxHeight: '60vh', overflow: 'auto' }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>Loading...</div>
          ) : !data?.ok ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#f87171', fontSize: 13 }}>{data?.error || 'Failed to load'}</div>
          ) : type === 'campaigns' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {filtered.map((c: any) => (
                <Link key={c.id} href={`/campaigns/${c.id}`} onClick={onClose} style={{ textDecoration: 'none', color: 'inherit', background: 'rgba(2,6,23,0.6)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 12, padding: 14, display: 'block', transition: 'border .2s' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, marginBottom: 8, flexWrap: 'wrap' }}>
                    <div style={{ fontWeight: 500, fontSize: 14, flex: 1, minWidth: 0 }}>{c.name}</div>
                    <span style={{
                      fontSize: 11, padding: '3px 10px', borderRadius: 999, fontWeight: 600,
                      background: c.status === 'RUNNING' ? 'rgba(59,130,246,0.15)' : c.status === 'COMPLETED' ? 'rgba(16,185,129,0.15)' : 'rgba(100,116,139,0.15)',
                      color: c.status === 'RUNNING' ? '#60a5fa' : c.status === 'COMPLETED' ? '#34d399' : '#94a3b8'
                    }}>{c.status}</span>
                  </div>
                  <div style={{ fontSize: 12, color: '#64748b', marginBottom: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.subject}</div>
                  <div className="grid grid-cols-4 gap-3" style={{ fontSize: 12 }}>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>TOTAL</div><div style={{ fontWeight: 600 }}>{c.totalCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>SENT</div><div style={{ fontWeight: 600, color: '#60a5fa' }}>{c.sentCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>FAILED</div><div style={{ fontWeight: 600, color: '#f87171' }}>{c.failedCount}</div></div>
                    <div><div style={{ fontSize: 10, color: '#475569' }}>DATE</div><div style={{ fontWeight: 600, fontSize: 11 }}>{new Date(c.createdAt).toLocaleDateString()}</div></div>
                  </div>
                </Link>
              ))}
              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>No campaigns</div>}
            </div>
          ) : (
            <>
              <table className="hidden md:table" style={{ width: '100%', fontSize: 12 }}>
                <thead style={{ color: '#64748b', textAlign: 'left', position: 'sticky', top: 0, background: '#0f1119' }}>
                  <tr>
                    <th style={{ padding: 10 }}>Email</th>
                    <th style={{ padding: 10 }}>Name</th>
                    <th style={{ padding: 10 }}>Status</th>
                    <th style={{ padding: 10 }}>Sender</th>
                    <th style={{ padding: 10 }}>Time</th>
                    <th style={{ padding: 10 }}>Error</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r: any) => (
                    <tr key={r.id} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                      <td style={{ padding: 10, fontFamily: 'monospace', fontSize: 11 }}>{r.email}</td>
                      <td style={{ padding: 10, color: '#94a3b8' }}>{r.name || '—'}</td>
                      <td style={{ padding: 10, fontWeight: 600 }} className={statusColor(r.status)}>{r.status}</td>
                      <td style={{ padding: 10, color: '#64748b', fontSize: 11 }}>{r.senderEmail || '—'}</td>
                      <td style={{ padding: 10, color: '#64748b', fontSize: 10 }}>
                        {r.sentAt ? new Date(r.sentAt).toLocaleString() : r.queuedAt ? new Date(r.queuedAt).toLocaleString() : '—'}
                      </td>
                      <td style={{ padding: 10, color: '#f87171', fontSize: 10, maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.error || ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="md:hidden">
                {filtered.map((r: any) => (
                  <div key={r.id} style={{ padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontFamily: 'monospace', fontSize: 12, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.email}</span>
                      <span className={statusColor(r.status)} style={{ fontSize: 11, fontWeight: 600, flexShrink: 0 }}>{r.status}</span>
                    </div>
                    {r.name && <div style={{ fontSize: 11, color: '#64748b' }}>{r.name}</div>}
                    {r.senderEmail && <div style={{ fontSize: 10, color: '#475569', marginTop: 2 }}>📤 {r.senderEmail}</div>}
                    {r.error && <div style={{ fontSize: 10, color: '#f87171', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.error}</div>}
                  </div>
                ))}
              </div>

              {filtered.length === 0 && <div style={{ textAlign: 'center', padding: '60px 0', color: '#64748b' }}>No items</div>}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function statusColor(s: string) {
  return s === 'DELIVERED' ? 'text-emerald-400' :
    s === 'SENT' ? 'text-blue-400' :
    s === 'FAILED' || s === 'BOUNCED' ? 'text-red-400' :
    s === 'SUPPRESSED' ? 'text-slate-500' :
    s === 'PROCESSING' ? 'text-purple-400' :
    'text-amber-400';
}
EOF
sed -i 's/\r$//' app/dashboard/live/page.tsx
echo "   ✅"

# ==========================================
# 7. Git push
# ==========================================
echo ""
echo "🌿 [7/7] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: premium layout — centered headers, fixed sidebar nav, all pages linked"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ ULTRA PREMIUM LAYOUT DEPLOYED"
echo "==============================================="
echo ""
echo "✨ What's new:"
echo "   ✓ All sidebar links visible (Dashboard, Manage, Activity, System)"
echo "   ✓ Mobile menu toggle fixed"
echo "   ✓ Live Dashboard title CENTERED"
echo "   ✓ More breathing room (32-40px padding)"
echo "   ✓ 4 sections in sidebar with headers"
echo "   ✓ Settings + Help links added"
echo "   ✓ Premium glassmorphism + shadows"
echo "   ✓ Wider sidebar (280px)"
echo "   ✓ Better card padding (28px)"
echo "   ✓ All pages verified + placeholders created if missing"
echo ""
echo "🎯 2-3 min baad refresh karo:"
echo "   https://emailcampaign-ten.vercel.app/dashboard/live"
echo ""
echo "📱 Mobile: Hard refresh (Incognito me kholo)"
echo "==============================================="