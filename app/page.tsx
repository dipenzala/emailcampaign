import Link from 'next/link';
import { Reveal } from '@/components/reveal';
import { Parallax } from '@/components/parallax';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      {/* NAV */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="container flex items-center justify-between h-14">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-7 h-7 rounded-lg bg-[#0071e3] flex items-center justify-center">
              <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="text-sm font-semibold tracking-tight">EmailCampaign</span>
          </Link>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-[#424245]">
            <a href="#features" className="hover:text-[#0071e3] transition-colors">Features</a>
            <a href="#workflow" className="hover:text-[#0071e3] transition-colors">Workflow</a>
            <a href="#security" className="hover:text-[#0071e3] transition-colors">Security</a>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-[#424245] hover:text-[#0071e3] transition-colors hidden sm:block">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-xs !px-4 !py-1.5">Get Started</Link>
          </div>
        </div>
      </nav>

      {/* ============ HERO ============ */}
      <section className="relative pt-32 pb-24 px-6 md:pt-40 md:pb-32">
        <div className="container relative z-10 text-center">
          <Reveal type="fade">
            <div className="badge mb-6 fade-up">
              <span className="badge-dot" />
              Now live · Powered by Gmail API
            </div>
          </Reveal>

          <Reveal type="up" delay={1}>
            <h1 className="headline max-w-4xl mx-auto">
              Send email<br />
              <span className="gradient-text">that lands.</span>
            </h1>
          </Reveal>

          <Reveal type="up" delay={2}>
            <p className="subhead">
              Premium email campaigns with intelligent sender rotation, seven-layer anti-spam protection, and real-time analytics. Built for teams who value deliverability.
            </p>
          </Reveal>

          <Reveal type="up" delay={3}>
            <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
              <Link href="/login" className="btn btn-primary btn-lg">
                Start Free Trial
              </Link>
              <a href="#features" className="btn btn-ghost btn-lg">
                Watch Demo →
              </a>
            </div>
          </Reveal>

          <Reveal type="up" delay={4}>
            <div className="mt-14 flex flex-wrap items-center justify-center gap-10 text-xs text-[#86868b]">
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                No credit card
              </span>
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                OAuth 2.0 secure
              </span>
              <span className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[#30d158]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                Cancel anytime
              </span>
            </div>
          </Reveal>
        </div>

        {/* Dashboard preview with cinematic reveal + parallax */}
        <div className="container relative mt-20 md:mt-28">
          <Reveal type="blur" delay={5}>
            <Parallax speed={0.08}>
              <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-black/[0.08] border border-black/[0.06] !rounded-3xl">
                <div className="flex items-center gap-2 px-5 py-3.5 border-b border-black/[0.06] bg-white/60">
                  <span className="w-3 h-3 rounded-full bg-[#ff5f57]" />
                  <span className="w-3 h-3 rounded-full bg-[#febc2e]" />
                  <span className="w-3 h-3 rounded-full bg-[#28c840]" />
                  <span className="ml-3 text-xs text-[#86868b] font-mono">campaign · live</span>
                  <span className="ml-auto flex items-center gap-1.5 text-xs text-[#30d158]">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#30d158] animate-pulse" />
                    Running
                  </span>
                </div>
                <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
                  {[
                    { l: 'SENT', v: '12,847', c: '#0071e3' },
                    { l: 'DELIVERED', v: '12,412', c: '#30d158' },
                    { l: 'PENDING', v: '435', c: '#ff9f0a' },
                    { l: 'FAILED', v: '12', c: '#ff3b30' },
                  ].map(s => (
                    <div key={s.l} className="bg-white border border-black/[0.06] rounded-2xl p-5">
                      <div className="text-[10px] tracking-[0.12em] text-[#86868b] font-medium">{s.l}</div>
                      <div className="text-3xl font-semibold mt-2 tracking-tight" style={{ color: s.c }}>{s.v}</div>
                    </div>
                  ))}
                </div>
                <div className="px-8 pb-8">
                  <div className="h-1.5 w-full bg-black/[0.05] rounded-full overflow-hidden">
                    <div className="h-full w-[96%] bg-[#0071e3] rounded-full transition-all duration-1000" />
                  </div>
                  <div className="flex justify-between text-xs text-[#86868b] mt-3">
                    <span>Campaign progress</span>
                    <span className="text-[#1d1d1f] font-medium">96.4%</span>
                  </div>
                </div>
              </div>
            </Parallax>
          </Reveal>
        </div>
      </section>

      {/* ============ FEATURES ============ */}
      <section id="features" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Features</div>
              <h2 className="headline-sm">
                Built with real infrastructure.<br />
                <span className="text-[#86868b]">Not templates.</span>
              </h2>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              {
                title: 'OAuth 2.0 Only',
                desc: 'Your Gmail password never touches our servers. Tokens encrypted with AES-256-GCM at rest.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                ),
              },
              {
                title: 'Real-time Dashboard',
                desc: 'Live counters streamed via Server-Sent Events. Pause, resume, or stop any campaign instantly.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                ),
              },
              {
                title: 'Smart Import',
                desc: 'Excel, CSV, and Google Sheets supported. Auto-validate, deduplicate, and filter disposables.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2" />
                  </svg>
                ),
              },
              {
                title: 'HTML Email Editor',
                desc: 'Paste your HTML. Live desktop + mobile preview. Automatic plain-text fallback for every message.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                  </svg>
                ),
              },
              {
                title: '7-Layer Anti-Spam',
                desc: 'Content spam checker, warm-up schedules, bounce handler, list hygiene, and rate guard.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                ),
              },
              {
                title: 'Sender Rotation',
                desc: 'Round-robin across 25+ Gmail accounts with per-sender batch limits and reputation tracking.',
                icon: (
                  <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                ),
              },
            ].map((f, i) => (
              <Reveal key={f.title} type="up" delay={((i % 3) + 1) as any}>
                <div className="tilt card card-hover h-full">
                  <div className="w-12 h-12 rounded-2xl bg-[#0071e3]/10 text-[#0071e3] flex items-center justify-center mb-5">
                    {f.icon}
                  </div>
                  <h3 className="text-lg font-semibold text-[#1d1d1f] mb-2">{f.title}</h3>
                  <p className="text-sm text-[#6e6e73] leading-relaxed">{f.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ============ WORKFLOW (sticky scroll) ============ */}
      <section id="workflow" className="section bg-gradient-to-b from-transparent via-[#f5f5f7] to-transparent">
        <div className="container">
          <Reveal type="up">
            <div className="text-center max-w-2xl mx-auto mb-20">
              <div className="eyebrow">Workflow</div>
              <h2 className="headline-sm">
                Three steps. Zero friction.
              </h2>
              <p className="subhead !text-base">
                From import to inbox in under two minutes.
              </p>
            </div>
          </Reveal>

          <div className="grid md:grid-cols-3 gap-5">
            {[
              { n: '01', title: 'Import', desc: 'Upload Excel, CSV, or connect Google Sheets. Validation happens automatically.' },
              { n: '02', title: 'Compose', desc: 'Paste your HTML. Preview on desktop and mobile. Send a test in one click.' },
              { n: '03', title: 'Launch', desc: 'Hit start. Watch live counters. Pause, resume, or stop anytime.' },
            ].map((s, i) => (
              <Reveal key={s.n} type="up" delay={((i % 3) + 1) as any}>
                <div className="card card-hover">
                  <div className="text-5xl font-semibold tracking-tighter text-[#0071e3]/30 mb-3">{s.n}</div>
                  <h3 className="text-xl font-semibold text-[#1d1d1f] mb-3">{s.title}</h3>
                  <p className="text-sm text-[#6e6e73] leading-relaxed">{s.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ============ SECURITY ============ */}
      <section id="security" className="section">
        <div className="container">
          <Reveal type="up">
            <div className="card !p-12 md:!p-16 !rounded-3xl bg-gradient-to-br from-[#0071e3] to-[#5e5ce6] text-white border-0 shadow-2xl shadow-[#0071e3]/20">
              <div className="max-w-2xl">
                <div className="eyebrow !text-white/70">Security</div>
                <h2 className="headline-sm !text-white mb-6">
                  Your data. Your senders.<br />
                  Your control.
                </h2>
                <p className="text-white/80 text-lg leading-relaxed mb-8 max-w-lg">
                  Tokens encrypted with AES-256-GCM. Sessions signed with HMAC-SHA256. Login rate-limited. Every action audited.
                </p>
                <div className="grid sm:grid-cols-2 gap-4">
                  {[
                    'AES-256-GCM encryption',
                    'HMAC-signed sessions',
                    'Login rate limiting',
                    'Full audit trail',
                    'OAuth 2.0 only',
                    'No password storage',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3">
                      <svg className="w-5 h-5 text-white/80 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      </svg>
                      <span className="text-sm text-white/90">{f}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ============ CTA ============ */}
      <section className="section text-center">
        <div className="container">
          <Reveal type="up">
            <h2 className="headline max-w-3xl mx-auto">
              Ready to <span className="gradient-text">launch?</span>
            </h2>
          </Reveal>
          <Reveal type="up" delay={1}>
            <p className="subhead mb-10">
              Invite-only access. Connect your Gmail. Start sending today.
            </p>
          </Reveal>
          <Reveal type="up" delay={2}>
            <Link href="/login" className="btn btn-primary btn-lg">
              Get Started →
            </Link>
          </Reveal>
        </div>
      </section>

      {/* ============ FOOTER ============ */}
      <footer className="border-t border-black/[0.06] py-12 bg-white/40 backdrop-blur">
        <div className="container">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-6 h-6 rounded-md bg-[#0071e3]" />
              <span className="text-xs text-[#86868b]">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-[#424245]">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-7 text-xs text-[#86868b]">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-[#1d1d1f] transition-colors" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-[#1d1d1f] transition-colors">Privacy</Link>
              <Link href="/terms" className="hover:text-[#1d1d1f] transition-colors">Terms</Link>
              <Link href="/refund" className="hover:text-[#1d1d1f] transition-colors">Refund</Link>
              <Link href="/login" className="hover:text-[#1d1d1f] transition-colors">Sign in</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
