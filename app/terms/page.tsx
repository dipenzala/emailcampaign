import Link from 'next/link';

export const metadata = {
  title: 'Terms of Service — EmailCampaign',
  description: 'The rules for using EmailCampaign.',
};

const LAST_UPDATED = 'October 3, 2026';

export default function TermsPage() {
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
            Legal · Terms
          </div>
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-tight animate-in-slow delay-1">
            Terms of <span className="gradient-text">Service</span>
          </h1>
          <p className="mt-6 text-slate-400 animate-in-slow delay-2">
            Last updated: <b className="text-slate-200">{LAST_UPDATED}</b>
          </p>
          <p className="mt-4 text-lg text-slate-400 max-w-xl mx-auto animate-in-slow delay-3">
            Please read these terms carefully before using EmailCampaign.
          </p>
        </div>
      </section>

      <section className="relative px-6 pb-12">
        <div className="max-w-5xl mx-auto grid md:grid-cols-3 gap-4">
          {[
            { icon: '📧', title: 'Fair use', desc: 'Legitimate campaigns only' },
            { icon: '🚫', title: 'Zero spam', desc: 'No unsolicited bulk email' },
            { icon: '⚖️', title: 'Compliance', desc: 'CAN-SPAM & GDPR ready' },
          ].map((f, i) => (
            <div key={f.title} className={`tilt card animate-in-slow delay-${i + 1}`}>
              <div className="text-3xl mb-3 floaty" style={{ animationDelay: `${i * 0.4}s` }}>{f.icon}</div>
              <div className="font-semibold">{f.title}</div>
              <div className="text-xs text-slate-400 mt-1">{f.desc}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="relative px-6 pb-32">
        <div className="max-w-3xl mx-auto card animate-in-slow delay-3 space-y-8">

          <Section n={1} title="Acceptance of Terms">
            <P>By accessing or using EmailCampaign ("the Service"), you agree to be bound by these Terms of Service. If you do not agree, do not use the Service.</P>
            <P>You must be at least 16 years old and capable of forming a binding contract to use the Service.</P>
          </Section>

          <Section n={2} title="Description of Service">
            <P>EmailCampaign is a platform that helps you send legitimate HTML email campaigns through your own authorized Gmail or Google Workspace accounts. The Service includes:</P>
            <Ul>
              <li>Contact import from Excel/CSV/Google Sheets</li>
              <li>HTML email editor with live preview</li>
              <li>Gmail OAuth-based sending</li>
              <li>Real-time delivery dashboard</li>
              <li>Sender rotation, warm-up, and anti-spam protections</li>
              <li>Suppression list and unsubscribe management</li>
            </Ul>
          </Section>

          <Section n={3} title="Your Account">
            <P>You are responsible for:</P>
            <Ul>
              <li>Maintaining the confidentiality of your account credentials.</li>
              <li>All activity that occurs under your account.</li>
              <li>Ensuring your use complies with all applicable laws (CAN-SPAM, GDPR, CASL, etc.).</li>
              <li>Promptly notifying us of unauthorized access.</li>
            </Ul>
          </Section>

          <Section n={4} title="Acceptable Use Policy">
            <P><b className="text-green-400">You MAY:</b></P>
            <Ul>
              <li>Send transactional or promotional emails to recipients who have opted in.</li>
              <li>Import your own contact lists that you have permission to use.</li>
              <li>Connect multiple Gmail accounts that you own or control.</li>
            </Ul>
            <P className="!mt-4"><b className="text-red-400">You MAY NOT:</b></P>
            <Ul>
              <li>Send unsolicited bulk email (spam).</li>
              <li>Send to purchased, rented, or scraped email lists.</li>
              <li>Attempt to bypass Gmail or Google's sending limits.</li>
              <li>Send phishing, malware, or fraudulent content.</li>
              <li>Impersonate another person or organization.</li>
              <li>Violate any email provider's terms of service.</li>
              <li>Use the Service for illegal activity of any kind.</li>
              <li>Circumvent suppression lists or unsubscribe requests.</li>
            </Ul>
            <P className="!mt-3 text-red-400">Violation may result in immediate account termination without refund.</P>
          </Section>

          <Section n={5} title="Email Compliance">
            <P>You agree to comply with all applicable email marketing laws, including but not limited to:</P>
            <Ul>
              <li><b>CAN-SPAM Act (US):</b> Accurate headers, clear unsubscribe, physical address.</li>
              <li><b>GDPR (EU):</b> Lawful basis for processing, right to erasure.</li>
              <li><b>CASL (Canada):</b> Express or implied consent required.</li>
              <li><b>PECR (UK):</b> Consent and unsubscribe requirements.</li>
            </Ul>
            <P>Every email sent through the Service automatically includes a List-Unsubscribe header and unsubscribe link.</P>
          </Section>

          <Section n={6} title="Gmail API Usage">
            <P>By connecting a Gmail account, you authorize EmailCampaign to send email on your behalf using the <code className="text-xs bg-white/10 px-1.5 py-0.5 rounded">gmail.send</code> scope only.</P>
            <P>You acknowledge that:</P>
            <Ul>
              <li>Your use of Gmail remains subject to Google's Terms of Service.</li>
              <li>Google may impose its own sending limits and rate restrictions.</li>
              <li>We do not and cannot bypass Google's security or quota systems.</li>
              <li>You can revoke access at any time via Google Account settings or by disconnecting the sender in our dashboard.</li>
            </Ul>
          </Section>

          <Section n={7} title="Fees & Payment">
            <P>The Service is currently free to use. If we introduce paid tiers, we will notify you in advance. All future fees will be clearly disclosed before charging.</P>
          </Section>

          <Section n={8} title="Intellectual Property">
            <P>You retain all rights to the content you upload (contacts, HTML, subject lines). We retain all rights to the Service, its code, design, and trademarks.</P>
            <P>You grant us a limited license to process your content solely for the purpose of operating the Service.</P>
          </Section>

          <Section n={9} title="Data Ownership">
            <P>Your data remains yours. We claim no ownership of your contact lists, email content, or sender accounts. See our <Link href="/privacy" className="text-blue-400 hover:underline">Privacy Policy</Link> for details on how we handle your data.</P>
          </Section>

          <Section n={10} title="Service Availability">
            <P>We aim for high availability but provide the Service "as is" and "as available." We do not guarantee:</P>
            <Ul>
              <li>100% uptime or error-free operation.</li>
              <li>Successful delivery of every email (depends on Gmail, recipient server, etc.).</li>
              <li>Any specific open, click, or conversion rate.</li>
            </Ul>
          </Section>

          <Section n={11} title="Limitation of Liability">
            <P>To the maximum extent permitted by law, EmailCampaign shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to:</P>
            <Ul>
              <li>Loss of profits, data, or goodwill.</li>
              <li>Gmail account suspension by Google.</li>
              <li>Damage to sender reputation.</li>
              <li>Any third-party claims arising from your campaigns.</li>
            </Ul>
            <P>Our total liability for any claim shall not exceed the amount you paid us in the 12 months preceding the claim (or ₹0 if the Service is free).</P>
          </Section>

          <Section n={12} title="Indemnification">
            <P>You agree to indemnify and hold harmless EmailCampaign and its operators from any claims, damages, or expenses arising from:</P>
            <Ul>
              <li>Your use of the Service.</li>
              <li>Your violation of these Terms.</li>
              <li>Your violation of any third-party rights.</li>
              <li>Content you send through the Service.</li>
            </Ul>
          </Section>

          <Section n={13} title="Termination">
            <P>We may suspend or terminate your account at any time for:</P>
            <Ul>
              <li>Violation of these Terms.</li>
              <li>Sending spam or abusive content.</li>
              <li>Excessive bounce or complaint rates.</li>
              <li>Legal or regulatory requirements.</li>
            </Ul>
            <P>You may terminate your account at any time from the dashboard or by contacting us.</P>
          </Section>

          <Section n={14} title="Modifications">
            <P>We may update these Terms from time to time. Material changes will be communicated via email or in-app notification at least 30 days before they take effect. Continued use after changes means acceptance.</P>
          </Section>

          <Section n={15} title="Governing Law">
            <P>These Terms are governed by the laws of India. Any disputes shall be resolved in the courts of Gujarat, India.</P>
          </Section>

          <Section n={16} title="Contact">
            <P>Questions about these Terms?</P>
            <Ul>
              <li><b>Email:</b> <a href="mailto:dipenzala1@gmail.com" className="text-blue-400 hover:underline">dipenzala1@gmail.com</a></li>
              <li><b>Website:</b> <a href="https://emailcampaign-ten.vercel.app" className="text-blue-400 hover:underline">emailcampaign-ten.vercel.app</a></li>
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

function P({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <p className={`text-slate-300 text-sm leading-relaxed ${className}`}>{children}</p>;
}

function Ul({ children }: { children: React.ReactNode }) {
  return <ul className="list-disc list-inside space-y-1.5 text-slate-300 text-sm leading-relaxed pl-2">{children}</ul>;
}
