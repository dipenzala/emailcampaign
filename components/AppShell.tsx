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
    <>
      <Sidebar mobileOpen={mobileOpen} setMobileOpen={setMobileOpen} />
      <div
        style={{
          minHeight: '100vh',
          paddingLeft: '280px',
          transition: 'padding-left .3s cubic-bezier(.22,1,.36,1)',
          paddingTop: '80px',
        }}
        className="app-main-wrapper"
      >
        <Topbar onMenuClick={() => setMobileOpen(true)} />
        <div
          style={{
            padding: '24px 40px 80px',
            maxWidth: '1320px',
            margin: '0 auto',
            width: '100%',
          }}
          className="app-content-wrapper"
        >
          {children}
        </div>
      </div>

      <style jsx global>{`
        @media (max-width: 900px) {
          .app-main-wrapper {
            padding-left: 0 !important;
            padding-top: 72px !important;
          }
          .app-content-wrapper {
            padding: 16px 14px 60px !important;
          }
        }
      `}</style>
    </>
  );
}
