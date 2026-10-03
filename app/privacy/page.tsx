import Link from 'next/link';

export const metadata = {
  title: 'Privacy Policy — EmailCampaign',
  description: 'How we collect, use, and protect your data.',
};

const LAST_UPDATED = 'October 3, 2026';

export default function PrivacyPage() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="aurora" aria-hidden />

      {/* Nav */}
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

      {/* Hero */}
      <section className="relative pt-40 pb-16 px-6">
        <div className="max-w-3xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs text-slate-300 mb-6 animate-in shimmer">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            Legal · Privacy
          </div>
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-tight animate-in-slow delay-1">
            Privacy <span className="gradient-text">Policy</span>
          </h1>
          <p className="mt-6 text-slate-400 animate-in-slow delay-2">
            Last updated: <b className="text-slate-200">{LAST_UPDATED}</b>
          </p>
          <p className="mt-4 text-lg text-slate-400 max-w-xl mx-auto animate-in-slow delay-3">
            Your privacy matters. Here's exactly what we do with your data — and what we don't.
          </p>
        </div>
      </section>

      {/* Quick facts */}
      <section className="relative px-6 pb-12">
        <div className="max-w-5xl mx-auto grid md:grid-cols-3 gap-4">
          {[
            { icon: '🔒', title: 'OAuth only', desc: 'We never see your Gmail password' },
            { icon: '🛡️', title: 'AES-256', desc: 'Tokens encrypted at rest' },
            { icon: '🚫', title: 'No selling', desc: 'We never sell your data' },
          ].map((f, i) => (
            <div key={f.title} className={`tilt card animate-in-slow delay-${i + 1}`}>
              <div className="text-3xl mb-3 floaty" style={{ animationDelay: `${i * 0.4}s` }}>{f.icon}</div>
              <div className="font-semibold">{f.title}</div>
              <div className="text-xs text-slate-400 mt-1">{f.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Content */}
      <section className="relative px-6 pb-32">
        <div className="max-w-3xl mx-auto card animate-in-slow delay-3 space-y-8">

          <Section n={1} title="Information We Collect">
            <P>We collect only the minimum data needed to operate the Service:</P>
            <Ul>
              <li><b>Account data:</b> Your email address and optional display name when you sign up.</li>
              <li><b>Gmail OAuth tokens:</b> Encrypted access and refresh tokens issued by Google when you connect a sender account. We never see or store your Gmail password.</li>
              <li><b>Contact data:</b> Email addresses, names, and custom fields you upload via Excel/CSV or Google Sheets for your campaigns.</li>
              <li><b>Campaign data:</b> Subject lines, HTML email content, sending schedules, and delivery statuses.</li>
              <li><b>Technical data:</b> IP address, browser type, and usage logs for security and debugging.</li>
            </Ul>
          </Section>

          <Section n={2} title="How We Use Your Information">
            <Ul>
              <li>To send email campaigns on your behalf through your connected Gmail account.</li>
              <li>To maintain suppression lists, unsubscribe records, and bounce handling.</li>
              <li>To track delivery status, failures, and reputation metrics.</li>
              <li>To prevent spam, abuse, and unauthorized access.</li>
              <li>To improve the Service through aggregated, anonymized analytics.</li>
            </Ul>
            <P className="!mt-3"><b>We do NOT:</b></P>
            <Ul>
              <li>Read your inbox, contacts, or any Gmail data beyond the <code className="text-xs bg-white/10 px-1.5 py-0.5 rounded">gmail.send</code> scope you authorize.</li>
              <li>Sell, rent, or share your data with third parties for marketing.</li>
              <li>Use your email lists for our own campaigns.</li>
            </Ul>
          </Section>

          <Section n={3} title="Data Security">
            <P>We take security seriously:</P>
            <Ul>
              <li><b>Encryption:</b> All OAuth tokens are encrypted with AES-256-GCM before being stored.</li>
              <li><b>HTTPS:</b> All traffic is encrypted in transit using TLS 1.3.</li>
              <li><b>Secure cookies:</b> Session cookies are HttpOnly, Secure, and SameSite=Lax.</li>
              <li><b>Access control:</b> Only authorized systems can access production data.</li>
              <li><b>Audit logs:</b> All sensitive operations are logged.</li>
            </Ul>
          </Section>

          <Section n={4} title="Data Retention">
            <P>We retain your data as long as your account is active. When you delete your account:</P>
            <Ul>
              <li>OAuth tokens are immediately revoked and deleted.</li>
              <li>Contacts and campaigns are deleted within 30 days.</li>
              <li>Anonymized analytics may be retained indefinitely.</li>
              <li>Legal compliance records may be retained longer as required by law.</li>
            </Ul>
          </Section>

          <Section n={5} title="Third-Party Services">
            <P>We use the following service providers to operate:</P>
            <Ul>
              <li><b>Google (Gmail API):</b> To send emails through your connected account.</li>
              <li><b>Neon:</b> PostgreSQL database hosting.</li>
              <li><b>Upstash:</b> Redis queue hosting.</li>
              <li><b>Vercel:</b> Application hosting and deployment.</li>
              <li><b>Northflank / Railway:</b> Background worker hosting.</li>
            </Ul>
            <P>Each provider is bound by their own privacy policy and only processes data on our instructions.</P>
          </Section>

          <Section n={6} title="Your Rights">
            <P>You have the right to:</P>
            <Ul>
              <li><b>Access</b> the personal data we hold about you.</li>
              <li><b>Correct</b> inaccurate data through the dashboard.</li>
              <li><b>Delete</b> your account and all associated data.</li>
              <li><b>Export</b> your data in a portable format.</li>
              <li><b>Withdraw consent</b> for Gmail access by disconnecting senders.</li>
              <li><b>Object</b> to processing by contacting us.</li>
            </Ul>
            <P className="!mt-4">To exercise these rights, email us at <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a>.</P>
          </Section>

          <Section n={7} title="Cookies">
            <P>We use minimal, essential cookies only:</P>
            <Ul>
              <li><b>ec_session:</b> Signed session token to keep you logged in. HttpOnly, Secure, 30-day expiry.</li>
            </Ul>
            <P>We do not use tracking, advertising, or third-party analytics cookies.</P>
          </Section>

          <Section n={8} title="Children's Privacy">
            <P>The Service is not intended for users under 16. We do not knowingly collect data from children.</P>
          </Section>

          <Section n={9} title="GDPR & CCPA Compliance">
            <P>For users in the EU, we comply with GDPR. For California residents, we comply with CCPA. We do not sell personal information.</P>
          </Section>

          <Section n={10} title="Changes to This Policy">
            <P>We may update this Privacy Policy. Material changes will be notified via email or in-app notice at least 30 days before taking effect.</P>
          </Section>

          <Section n={11} title="Contact Us">
            <P>Questions or concerns? Reach out:</P>
            <Ul>
              <li><b>Email:</b> <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a></li>
              <li><b>Website:</b> <a href="https://emailcampaign-ten.vercel.app" className="text-blue-400 hover:underline">emailcampaign-ten.vercel.app</a></li>
            </Ul>
          </Section>

        </div>
      </section>

      {/* Footer */}
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

function P({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <p className={`text-slate-300 text-sm leading-relaxed ${className}`}>{children}</p>;
}

function Ul({ children }: { children: React.ReactNode }) {
  return <ul className="list-disc list-inside space-y-1.5 text-slate-300 text-sm leading-relaxed pl-2">{children}</ul>;
}
