import Link from 'next/link';
import { Reveal } from '@/components/reveal';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      {/* NAV */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="relative w-9 h-9 rounded-xl overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff] to-[#7c5cff]" />
              <div className="absolute inset-0 bg-gradient-to-br from-white/30 to-transparent" />
              <svg className="relative w-full h-full p-2 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="text-sm font-semibold tracking-tight text-white">EmailCampaign</span>
          </Link>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-[var(--fg-soft)]">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#workflow" className="hover:text-white transition-colors">Workflow</a>
            <a href="#security" className="hover:text-white transition-colors">Security</a>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-[var(--fg-soft)] hover:text-white transition-colors hidden sm:block">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-xs !px-4 !py-2">Get Started</Link>
          </div>
        </div>
      </nav>

      {/* HERO */}
      <section className="relative pt-36 pb-24 px-6 md:pt-48 md:pb-32">
        <div className="container relative z-10 text-center">
          <Reveal type="fade">
            <div className="badge mb-8 fade-up">
              <span className="badge-dot" />
              Powered by Gmail API · OAuth 2.0
            </div>
          </Reveal>

          <Reveal type="up" delay={1}>
            <h1 className="headline max-w-5xl mx-auto">
              Send email<br />
              <span className="gradient-text">that lands.</span>
            </h1>
          </Reveal>

          <Reveal type="up" delay={2}>
            <p className="subhead mx-auto text-center mt-8">
              Production-grade email campaigns with intelligent sender rotation, seven-layer anti-spam, and real-time analytics. Built for teams that care about deliverability.
            </p>
          </Reveal>

          <Reveal type="up" delay={3}>
            <div className="mt-12 flex flex-wrap items-center justify-center gap-4">
              <Link href="/login" className="btn btn-primary btn-lg">
                Start Free Trial
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </Link>
              <a href="#features" className="btn btn-ghost btn-lg">
                Explore Features
              </a>
            </div>
          </Reveal>

          <Reveal type="up" delay={4}>
            <div className="mt-16 flex flex-wrap items-center justify-center gap-8 text-xs text-[var(--fg-muted)]">
              {['No credit card', 'OAuth 2.0 secure', 'Cancel anytime'].map((t) => (
                <span key={t} className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-[var(--emerald)]" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  {t}
                </span>
              ))}
            </div>
          </Reveal>
        </div>

        {/* Dashboard preview */}
        <div className="container relative mt-24">
          <Reveal type="blur" delay={5}>
            <div className="tilt card !p-0 overflow-hidden !rounded-2xl">
              <div className="flex items-center gap-2 px-5 py-3.5 border-b border-white/[0.06]">
                <span className="w-3 h-3 rounded-full bg-[#ff5f57]" />
                <span className="w-3 h-3 rounded-full bg-[#febc2e]" />
                <span className="w-3 h-3 rounded-full bg-[#28c840]" />
                <span className="ml-3 text-xs text-[var(--fg-dim)] font-mono">campaign · live</span>
                <span className="ml-auto flex items-center gap-1.5 text-xs text-[var(--emerald)]">
                  <span className="w-1.5 h-1.5 rounded-full bg-[var(--emerald)] animate-pulse" />
                  Running
                </span>
              </div>
              <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
                {[
                  { l: 'SENT', v: '12,847', c: 'var(--accent)' },
                  { l: 'DELIVERED', v: '12,412', c: 'var(--emerald)' },
                  { l: 'PENDING', v: '435', c: 'var(--amber)' },
                  { l: 'FAILED', v: '12', c: 'var(--red)' },
                ].map(s => (
                  <div key={s.l} className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-5">
                    <div className="text-[10px] tracking-[0.15em] text-[var(--fg-dim)] font-medium">{s.l}</div>
                    <div className="text-3xl font-semibold mt-2 tracking-tight" style={{ color: s.c }}>{s.v}</div>
                  </div>
                ))}
              </div>
              <div className="px-8 pb-8">
                <div className="h-1.5 w-full bg-white/[0.04] rounded-full overflow-hidden">
                  <div className="h-full w-[96%] bg-gradient-to-r from-[#4f9cff] via-[#6db1ff] to-[#30d158] rounded-full" />
                </div>
                <div className="flex justify-between text-xs text-[var(--fg-dim)] mt-3">
                  <span>Campaign progress</span>
                  <span className="text-white font-medium">96.4%</span>
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Features</div>
              <h2 className="headline-sm">
                Built with real infrastructure.
              </h2>
              <p className="subhead mx-auto mt-5">
                Every feature engineered for scale. No shortcuts, no fake numbers.
              </p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { title: 'OAuth 2.0 Only', desc: 'Your Gmail password never touches our servers. Tokens encrypted with AES-256-GCM at rest.', icon: 'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z' },
              { title: 'Real-time Dashboard', desc: 'Live counters via Server-Sent Events. Pause, resume, or stop any campaign instantly.', icon: 'M13 10V3L4 14h7v7l9-11h-7z' },
              { title: 'Smart Import', desc: 'Excel, CSV, Google Sheets. Auto-validate, dedupe, and filter disposables.', icon: 'M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2' },
              { title: 'HTML Email Editor', desc: 'Paste your HTML. Live desktop + mobile preview. Automatic plain-text fallback.', icon: 'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4' },
              { title: '7-Layer Anti-Spam', desc: 'Content checker, warm-up schedules, bounce handler, list hygiene, and rate guard.', icon: 'M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z' },
              { title: 'Sender Rotation', desc: 'Round-robin across 25+ Gmail accounts with per-sender batch limits and reputation.', icon: 'M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15' },
            ].map((f, i) => (
              <Reveal key={f.title} type="up" delay={((i % 3) + 1) as any}>
                <div className="tilt card card-hover h-full">
                  <div className="w-11 h-11 rounded-xl flex items-center justify-center mb-5" style={{
                    background: 'linear-gradient(135deg, rgba(79, 156, 255, 0.15) 0%, rgba(124, 92, 255, 0.1) 100%)',
                    border: '1px solid rgba(79, 156, 255, 0.2)',
                  }}>
                    <svg className="w-5 h-5 text-[var(--accent)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                      <path strokeLinecap="round" strokeLinejoin="round" d={f.icon} />
                    </svg>
                  </div>
                  <h3 className="text-base font-semibold text-white mb-2">{f.title}</h3>
                  <p className="text-sm text-[var(--fg-soft)] leading-relaxed">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* WORKFLOW */}
      <section id="workflow" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Workflow</div>
              <h2 className="headline-sm">Three steps. Zero friction.</h2>
              <p className="subhead mx-auto mt-5">From import to inbox in under two minutes.</p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { n: '01', title: 'Import', desc: 'Upload Excel, CSV, or connect Google Sheets. Validation happens automatically.' },
              { n: '02', title: 'Compose', desc: 'Paste HTML. Preview on desktop and mobile. Send a test in one click.' },
              { n: '03', title: 'Launch', desc: 'Hit start. Watch live counters. Pause, resume, or stop anytime.' },
            ].map((s, i) => (
              <Reveal key={s.n} type="up" delay={((i % 3) + 1) as any}>
                <div className="card card-hover h-full relative overflow-hidden">
                  <div className="absolute top-4 right-5 text-6xl font-black text-white/[0.03] tracking-tighter">{s.n}</div>
                  <div className="relative">
                    <div className="text-4xl font-semibold tracking-tighter gradient-text mb-4">{s.n}</div>
                    <h3 className="text-lg font-semibold text-white mb-2">{s.title}</h3>
                    <p className="text-sm text-[var(--fg-soft)] leading-relaxed">{s.desc}</p>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* SECURITY */}
      <section id="security" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="card !p-12 md:!p-16 !rounded-3xl overflow-hidden relative">
              <div className="absolute inset-0 bg-gradient-to-br from-[#4f9cff]/10 via-transparent to-[#7c5cff]/10" />
              <div className="absolute top-0 right-0 w-96 h-96 bg-[#4f9cff]/10 rounded-full blur-[120px]" />
              <div className="relative">
                <div className="eyebrow">Security</div>
                <h2 className="headline-sm !max-w-2xl">
                  Your data. Your senders. Your control.
                </h2>
                <p className="text-[var(--fg-soft)] text-lg leading-relaxed mt-6 max-w-lg">
                  Tokens encrypted with AES-256-GCM. Sessions signed with HMAC-SHA256. Login rate-limited. Every action audited.
                </p>
                <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-10">
                  {[
                    'AES-256-GCM encryption',
                    'HMAC-signed sessions',
                    'Login rate limiting',
                    'Device-bound sessions',
                    'OAuth 2.0 only',
                    'No password storage',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3">
                      <div className="w-5 h-5 rounded-md bg-[var(--emerald)]/20 flex items-center justify-center flex-shrink-0">
                        <svg className="w-3 h-3 text-[var(--emerald)]" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <span className="text-sm text-[var(--fg-soft)]">{f}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* CTA */}
      <section className="section text-center">
        <div className="container">
          <Reveal type="up">
            <h2 className="headline max-w-3xl mx-auto">
              Ready to <span className="gradient-text">launch?</span>
            </h2>
          </Reveal>
          <Reveal type="up" delay={1}>
            <p className="subhead mx-auto text-center mt-6 mb-10">
              Invite-only access. Connect your Gmail. Start sending today.
            </p>
          </Reveal>
          <Reveal type="up" delay={2}>
            <Link href="/login" className="btn btn-primary btn-lg">
              Get Started
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </Link>
          </Reveal>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="relative border-t border-white/[0.06] py-12">
        <div className="container">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#4f9cff] to-[#7c5cff]" />
              <span className="text-xs text-[var(--fg-muted)]">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-white">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-xs text-[var(--fg-muted)]">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-white transition-colors" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-white transition-colors">Privacy</Link>
              <Link href="/terms" className="hover:text-white transition-colors">Terms</Link>
              <Link href="/refund" className="hover:text-white transition-colors">Refund</Link>
              <Link href="/login" className="hover:text-white transition-colors">Sign in</Link>
            </div>
          </div>
          <div className="mt-6 pt-6 border-t border-white/[0.04] flex flex-wrap items-center justify-center md:justify-between gap-4 text-xs">
            <span className="text-[var(--fg-dim)]">Help & Support:</span>
            <div className="flex items-center gap-4">
              <a href="tel:+918128931029" className="text-[var(--accent)] hover:underline font-medium">📞 +91 8128931029</a>
              <a href="https://wa.me/918128931029" className="text-[#25D366] hover:underline font-medium" target="_blank" rel="noopener">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
