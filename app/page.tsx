import Link from 'next/link';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      <div className="aurora" aria-hidden />

      {/* Nav */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-violet-500 via-fuchsia-500 to-pink-500 flex items-center justify-center shadow-lg shadow-violet-500/30 group-hover:scale-110 transition-transform">
              <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <span className="font-bold tracking-tight text-slate-900">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-3">
            <a href="#features" className="hidden md:block text-sm font-medium text-slate-600 hover:text-slate-900 transition">Features</a>
            <Link href="/login" className="text-sm font-medium text-slate-600 hover:text-slate-900 transition">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-sm">Get Started →</Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative pt-40 pb-24 px-6">
        <div className="max-w-5xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/70 backdrop-blur border border-violet-200 text-xs font-medium text-slate-700 mb-8 animate-in shimmer shadow-sm">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            Now live · Powered by Gmail API
          </div>

          <h1 className="text-5xl md:text-7xl lg:text-8xl font-black tracking-tight leading-[0.98] text-slate-900 animate-in-slow delay-1">
            Send email<br />
            <span className="gradient-text">that converts.</span>
          </h1>

          <p className="mt-8 text-lg md:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            Production-grade email campaigns with sender rotation, anti-spam protection, and real-time analytics. Built for teams who care about deliverability.
          </p>

          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-8 py-3.5 !text-base">
              Start Campaign →
            </Link>
            <a href="#features" className="btn btn-ghost text-base px-8 py-3.5">
              See Features
            </a>
          </div>

          {/* Stats */}
          <div className="mt-20 grid grid-cols-3 gap-6 max-w-2xl mx-auto animate-in-slow delay-4">
            {[
              { v: '25+', l: 'Sender Accounts' },
              { v: '99.9%', l: 'Uptime' },
              { v: '7-Layer', l: 'Anti-Spam' },
            ].map((s, i) => (
              <div key={s.l} className="text-center">
                <div className="text-3xl md:text-4xl font-bold gradient-text">{s.v}</div>
                <div className="text-xs text-slate-500 mt-1">{s.l}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Floating dashboard preview */}
        <div className="relative max-w-5xl mx-auto mt-20 animate-in-slow delay-5">
          <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-violet-500/20">
            <div className="flex items-center gap-2 px-4 py-3 border-b border-slate-100 bg-white/50">
              <span className="w-3 h-3 rounded-full bg-red-400" />
              <span className="w-3 h-3 rounded-full bg-amber-400" />
              <span className="w-3 h-3 rounded-full bg-green-400" />
              <span className="ml-3 text-xs text-slate-400 font-mono">campaign · live</span>
            </div>
            <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4 bg-white/40">
              {[
                { l: 'SENT', v: '12,847', c: 'from-blue-500 to-blue-600' },
                { l: 'DELIVERED', v: '12,412', c: 'from-green-500 to-emerald-600' },
                { l: 'PENDING', v: '435', c: 'from-amber-500 to-orange-500' },
                { l: 'FAILED', v: '12', c: 'from-red-500 to-rose-600' },
              ].map(s => (
                <div key={s.l} className="bg-white border border-slate-100 rounded-xl p-4 shadow-sm">
                  <div className="text-[10px] tracking-widest text-slate-400 font-medium">{s.l}</div>
                  <div className={`text-2xl font-bold mt-1 bg-gradient-to-r ${s.c} bg-clip-text text-transparent`}>{s.v}</div>
                </div>
              ))}
            </div>
            <div className="px-8 pb-8 bg-white/40">
              <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
                <div className="h-full w-[96%] bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full" />
              </div>
              <div className="flex justify-between text-xs text-slate-400 mt-2">
                <span>Progress</span>
                <span className="font-medium text-slate-600">96.4%</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="relative py-28 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-black tracking-tight text-slate-900">
              Everything you need. <span className="gradient-text">Nothing you don't.</span>
            </h2>
            <p className="mt-5 text-slate-600 max-w-xl mx-auto">
              Built with real infrastructure — Postgres, Redis, BullMQ, Gmail API.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: '🔒', title: 'OAuth 2.0 Only', desc: 'We never see your Gmail password. Tokens AES-256 encrypted at rest.', color: 'from-violet-500 to-purple-600' },
              { icon: '⚡', title: 'Real-time Dashboard', desc: 'Live counters, SSE updates, pause/resume/stop any time.', color: 'from-blue-500 to-cyan-600' },
              { icon: '📊', title: 'Excel + Sheets', desc: 'Import .xlsx, .csv. Auto-validate, dedupe, hygiene filter.', color: 'from-green-500 to-emerald-600' },
              { icon: '🎨', title: 'HTML Editor', desc: 'Paste HTML. Live preview. Plain-text fallback. Personalization vars.', color: 'from-pink-500 to-rose-600' },
              { icon: '🛡️', title: '7-Layer Anti-Spam', desc: 'Spam checker, warm-up, bounce handler, list hygiene, rate guard.', color: 'from-amber-500 to-orange-600' },
              { icon: '🔄', title: 'Sender Rotation', desc: 'Round-robin 25+ senders. Batch limit. Warm-up schedule.', color: 'from-fuchsia-500 to-pink-600' },
            ].map((f, i) => (
              <div key={f.title} className={`tilt card animate-in-slow delay-${(i % 5) + 1} group`}>
                <div className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${f.color} flex items-center justify-center text-2xl mb-5 shadow-lg group-hover:scale-110 transition-transform duration-500`}>
                  <span>{f.icon}</span>
                </div>
                <h3 className="font-bold text-lg mb-2 text-slate-900">{f.title}</h3>
                <p className="text-sm text-slate-600 leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="relative py-28 px-6">
        <div className="max-w-3xl mx-auto text-center relative z-10">
          <h2 className="text-4xl md:text-6xl font-black tracking-tight text-slate-900 mb-6">
            Ready to <span className="gradient-text">launch?</span>
          </h2>
          <p className="text-slate-600 mb-10 text-lg">
            Invite-only access. Connect your Gmail. Start sending today.
          </p>
          <Link href="/login" className="btn btn-primary text-base px-10 py-4 !text-base">
            Get Started →
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-slate-200 py-12 px-6 bg-white/50 backdrop-blur">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-3">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
              <span className="text-sm text-slate-500">
                © {new Date().getFullYear()} EmailCampaign · <b className="text-slate-700">Created by DIPEN ZALA</b>
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-6 text-sm text-slate-500">
              <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-slate-900 transition" target="_blank" rel="noopener">GitHub</a>
              <Link href="/privacy" className="hover:text-slate-900 transition">Privacy</Link>
              <Link href="/terms" className="hover:text-slate-900 transition">Terms</Link>
              <Link href="/refund" className="hover:text-slate-900 transition">Refund</Link>
              <Link href="/login" className="hover:text-slate-900 transition">Sign in</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
