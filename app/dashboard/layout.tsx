import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { verifySession } from '@/lib/session';
import LogoutButton from './logout-button';

export const dynamic = 'force-dynamic';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) redirect('/login');

  return (
    <div className="min-h-screen">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 via-fuchsia-500 to-pink-500 flex items-center justify-center shadow-md shadow-violet-500/30">
              <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-bold tracking-tight text-sm text-slate-900">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-1 flex-wrap">
            <Link href="/dashboard" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Campaign</Link>
            <Link href="/senders" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Senders</Link>
            <Link href="/senders/rotation" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">Rotation</Link>
            <Link href="/anti-spam" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">🛡️ Anti-Spam</Link>
            <Link href="/team" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">👥 Team</Link>
            <Link href="/history" className="text-sm text-slate-600 hover:text-slate-900 hover:bg-white/60 px-3 py-1.5 rounded-lg transition font-medium">History</Link>
            <div className="w-px h-5 bg-slate-200 mx-2" />
            <span className="text-xs text-slate-500 hidden md:inline font-medium">
              @{session.username} {session.role === 'owner' && <span className="text-amber-500">●</span>}
            </span>
            <LogoutButton />
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
      <footer className="max-w-7xl mx-auto px-6 py-8 text-center text-xs text-slate-400">
        © {new Date().getFullYear()} EmailCampaign · <b className="text-slate-600">Created by DIPEN ZALA</b>
      </footer>
    </div>
  );
}
