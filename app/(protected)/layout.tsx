import { requireAuth } from '@/lib/auth-guard';
import Nav from '@/components/nav';
import HelpContact from '@/components/help-contact';

export const dynamic = 'force-dynamic';

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const session = await requireAuth();

  return (
    <div className="min-h-screen">
      <Nav username={session.username} role={session.role} />

      <main className="max-w-7xl mx-auto px-4 md:px-6 py-6 md:py-8">
        {children}
      </main>

      <footer className="max-w-7xl mx-auto px-4 md:px-6 py-8 mt-8 border-t border-white/[0.05]">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="text-[var(--fg-muted)]">
            © {new Date().getFullYear()} EmailCampaign · <b className="text-white">Created by DIPEN ZALA</b>
          </div>
          <div className="flex items-center gap-5">
            <span className="text-[var(--fg-dim)]">Help:</span>
            <a href="tel:+918128931029" className="text-[var(--accent)] hover:underline font-medium">📞 8128931029</a>
            <a href="https://wa.me/918128931029" target="_blank" rel="noopener" className="text-[#25D366] hover:underline font-medium">💬 WhatsApp</a>
          </div>
        </div>
      </footer>

      <HelpContact />
    </div>
  );
}
