import Link from 'next/link';

export const metadata = {
  title: 'Refund Policy — EmailCampaign',
  description: 'Refund and cancellation policy.',
};

const LAST_UPDATED = 'October 3, 2026';

export default function RefundPage() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="aurora" aria-hidden />

      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-pink-500 group-hover:scale-110 transition" />
            <span className="font-semibold tracking-tight">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm text-slate-300 hover:text-white transition">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-sm">Get started</Link>
          </div>
        </div>
      </nav>

      <section className="relative pt-40 pb-16 px-6">
        <div className="max-w-3xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs text-slate-300 mb-6 animate-in shimmer">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            Legal · Refund
          </div>
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-tight animate-in-slow delay-1">
            Refund <span className="gradient-text">Policy</span>
          </h1>
          <p className="mt-6 text-slate-400 animate-in-slow delay-2">
            Last updated: <b className="text-slate-200">{LAST_UPDATED}</b>
          </p>
        </div>
      </section>

      <section className="relative px-6 pb-32">
        <div className="max-w-3xl mx-auto card animate-in-slow delay-3 space-y-8">

          <Section n={1} title="Current Pricing">
            <P><b>EmailCampaign is currently free to use.</b> No payment is required for any feature currently offered. This policy will be updated if we introduce paid tiers.</P>
          </Section>

          <Section n={2} title="Future Paid Plans">
            <P>If we introduce paid plans in the future:</P>
            <Ul>
              <li>All pricing will be clearly displayed before you commit.</li>
              <li>You will be able to cancel at any time from your dashboard.</li>
              <li>Existing free-tier users will be notified at least 30 days in advance.</li>
            </Ul>
          </Section>

          <Section n={3} title="Cancellation">
            <P>You can cancel your account at any time:</P>
            <Ul>
              <li>From the dashboard settings.</li>
              <li>By emailing us at <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a>.</li>
            </Ul>
            <P>Cancellation stops all future billing. Your data will be deleted within 30 days.</P>
          </Section>

          <Section n={4} title="Refund Eligibility (Future Paid Plans)">
            <P>If we introduce paid plans, refunds will be considered under these terms:</P>
            <Ul>
              <li><b>Within 7 days</b> of initial purchase — full refund if unused.</li>
              <li><b>Within 30 days</b> — partial refund if significantly underused.</li>
              <li><b>After 30 days</b> — no refund for past periods.</li>
              <li><b>Service outage</b> exceeding 48 continuous hours — pro-rated credit.</li>
            </Ul>
          </Section>

          <Section n={5} title="Non-Refundable Cases">
            <P>Refunds will not be issued for:</P>
            <Ul>
              <li>Account termination due to Terms of Service violations.</li>
              <li>Gmail account suspension by Google.</li>
              <li>Dissatisfaction with email delivery rates (outside our control).</li>
              <li>Failure to use the Service after purchase.</li>
            </Ul>
          </Section>

          <Section n={6} title="How to Request">
            <P>To request a refund (for future paid plans):</P>
            <Ul>
              <li>Email <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a> with subject "Refund Request".</li>
              <li>Include your account email and reason.</li>
              <li>We will respond within 5 business days.</li>
              <li>Approved refunds are processed within 7-14 business days.</li>
            </Ul>
          </Section>

          <Section n={7} title="Contact">
            <P>Questions about refunds?</P>
            <Ul>
              <li><b>Email:</b> <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a></li>
            </Ul>
          </Section>

        </div>
      </section>

      <footer className="relative border-t border-white/5 py-10 px-6">
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-slate-500">
          <div>© {new Date().getFullYear()} EmailCampaign. All rights reserved.</div>
          <div className="flex gap-6">
            <Link href="/privacy" className="hover:text-white transition">Privacy</Link>
            <Link href="/terms" className="hover:text-white transition">Terms</Link>
            <Link href="/refund" className="hover:text-white transition">Refund</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}

function Section({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="flex items-center gap-3 mb-3">
        <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center text-xs font-bold flex-shrink-0">
          {n}
        </div>
        <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
      </div>
      <div className="space-y-2 text-slate-300 text-sm leading-relaxed">{children}</div>
    </div>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="text-slate-300 text-sm leading-relaxed">{children}</p>;
}

function Ul({ children }: { children: React.ReactNode }) {
  return <ul className="list-disc list-inside space-y-1.5 text-slate-300 text-sm leading-relaxed pl-2">{children}</ul>;
}
