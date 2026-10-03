#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 📄 EmailCampaign — Verify + Legal Pages"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF fix ----------
echo ""
echo "🔧 [1/6] CRLF fix..."
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.html" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅"

# ---------- 2. Google verification file ----------
echo ""
echo "📝 [2/6] Google verification file..."
mkdir -p public
printf "google-site-verification: googleb2ddc6e79cf4973a.html\n" > public/googleb2ddc6e79cf4973a.html
sed -i 's/\r$//' public/googleb2ddc6e79cf4973a.html
echo "   ✅ public/googleb2ddc6e79cf4973a.html"

# ---------- 3. Privacy Policy ----------
echo ""
echo "📄 [3/6] Privacy Policy..."

mkdir -p app/privacy
cat > app/privacy/page.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' app/privacy/page.tsx
echo "   ✅ /privacy page"

# ---------- 4. Terms of Service ----------
echo ""
echo "📄 [4/6] Terms of Service..."

mkdir -p app/terms
cat > app/terms/page.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' app/terms/page.tsx
echo "   ✅ /terms page"

# ---------- 5. Refund Policy ----------
echo ""
echo "📄 [5/6] Refund Policy..."

mkdir -p app/refund
cat > app/refund/page.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' app/refund/page.tsx
echo "   ✅ /refund page"

# ---------- 6. Update landing footer with legal links ----------
echo ""
echo "🔗 [6/6] Update landing footer..."

if [ -f "app/page.tsx" ]; then
  if ! grep -q 'href="/privacy"' app/page.tsx; then
    # Replace the simple footer with an enhanced one containing legal links
    node <<'NODEEOF'
const fs = require('fs');
let s = fs.readFileSync('app/page.tsx', 'utf8');

// Find the existing footer section
const footerRegex = /<footer[\s\S]*?<\/footer>/;
const newFooter = `<footer className="relative border-t border-white/5 py-12 px-6">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
              <span className="text-sm text-slate-400">© {new Date().getFullYear()} EmailCampaign</span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-sm text-slate-500">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-white transition" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-white transition">Privacy</Link>
              <Link href="/terms" className="hover:text-white transition">Terms</Link>
              <Link href="/refund" className="hover:text-white transition">Refund</Link>
              <Link href="/login" className="hover:text-white transition">Sign in</Link>
            </div>
          </div>
        </div>
      </footer>`;

s = s.replace(footerRegex, newFooter);
fs.writeFileSync('app/page.tsx', s);
console.log('   ✅ Landing footer updated');
NODEEOF
    sed -i 's/\r$//' app/page.tsx
  else
    echo "   ℹ️  Footer already has legal links"
  fi
fi

# ---------- 7. Git ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Add: privacy, terms, refund + Google verification file"
  echo "   ✅ Committed"
fi

echo ""
echo "🚀 Pushing..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ DONE"
echo "==================================================="
echo ""
echo "⏱️  Vercel 2-3 min me deploy karega"
echo ""
echo "📋 Files added:"
echo "   ✅ public/googleb2ddc6e79cf4973a.html   (Google verify)"
echo "   ✅ /privacy                              (Privacy Policy)"
echo "   ✅ /terms                                (Terms of Service)"
echo "   ✅ /refund                               (Refund Policy)"
echo ""
echo "🔗 Test URLs (deploy ke baad):"
echo "   https://emailcampaign-ten.vercel.app/privacy"
echo "   https://emailcampaign-ten.vercel.app/terms"
echo "   https://emailcampaign-ten.vercel.app/refund"
echo ""
echo "🔍 Verify URL:"
echo "   https://emailcampaign-ten.vercel.app/googleb2ddc6e79cf4973a.html"
echo ""
echo "📸 Google Search Console me:"
echo "   1. Upar URL kholo → text dikhna chahiye"
echo "   2. VERIFY button dabao → done!"
echo "==================================================="