import Link from 'next/link';

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      {/* Aurora background */}
      <div className="aurora" aria-hidden />

      {/* Nav */}
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-pink-500 group-hover:scale-110 transition" />
            <span className="font-semibold tracking-tight">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm text-slate-300 hover:text-white transition">
              Sign in
            </Link>
            <Link href="/login" className="btn btn-primary text-sm">
              Get started
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative pt-40 pb-32 px-6">
        <div className="max-w-5xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs text-slate-300 mb-8 animate-in shimmer">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            Powered by Gmail API · OAuth 2.0
          </div>

          <h1 className="text-5xl md:text-7xl lg:text-8xl font-semibold tracking-tight leading-[1.02] animate-in-slow delay-1">
            Send email
            <br />
            <span className="gradient-text">that feels personal.</span>
          </h1>

          <p className="mt-8 text-lg md:text-xl text-slate-400 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            A production-ready campaign platform. Import contacts, paste your HTML,
            hit send — watch it fly in real-time. No spam, no shortcuts, just clean delivery.
          </p>

          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-7 py-3">
              Start a campaign →
            </Link>
            <a href="#features" className="btn btn-ghost text-base px-7 py-3">
              See features
            </a>
          </div>

          <div className="mt-20 text-xs text-slate-500 animate-in-slow delay-4">
            No credit card · Bring your own Gmail · Free to start
          </div>
        </div>

        {/* Floating preview card */}
        <div className="relative max-w-4xl mx-auto mt-24 animate-in-slow delay-5">
          <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-violet-500/10">
            <div className="flex items-center gap-2 px-4 py-3 border-b border-white/5 bg-white/[0.02]">
              <span className="w-3 h-3 rounded-full bg-red-400/70" />
              <span className="w-3 h-3 rounded-full bg-yellow-400/70" />
              <span className="w-3 h-3 rounded-full bg-green-400/70" />
              <span className="ml-3 text-xs text-slate-500">campaign · live</span>
            </div>
            <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: 'SENT', value: '12,847', color: 'text-blue-400' },
                { label: 'DELIVERED', value: '12,412', color: 'text-emerald-400' },
                { label: 'PENDING', value: '435', color: 'text-amber-400' },
                { label: 'FAILED', value: '12', color: 'text-red-400' },
              ].map((s) => (
                <div key={s.label} className="bg-white/[0.03] border border-white/5 rounded-xl p-4">
                  <div className="text-[10px] tracking-widest text-slate-500">{s.label}</div>
                  <div className={`text-2xl font-semibold mt-1 ${s.color}`}>{s.value}</div>
                </div>
              ))}
            </div>
            <div className="px-8 pb-8">
              <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                <div className="h-full w-[96%] bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full" />
              </div>
              <div className="flex justify-between text-xs text-slate-500 mt-2">
                <span>Progress</span>
                <span>96.4%</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="relative py-32 px-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-20">
            <h2 className="text-4xl md:text-5xl font-semibold tracking-tight">
              Everything you need. <span className="gradient-text">Nothing you don't.</span>
            </h2>
            <p className="mt-6 text-slate-400 max-w-xl mx-auto">
              Built with real infrastructure. Postgres, Redis, BullMQ, Gmail API.
              Runs on Vercel + any Node host.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              { icon: '🔒', title: 'OAuth 2.0 only', desc: 'We never see your Gmail password. Tokens are AES-256-GCM encrypted at rest.' },
              { icon: '⚡', title: 'Real-time dashboard', desc: 'Server-sent events stream live counters. Pause, resume, stop — instantly.' },
              { icon: '📊', title: 'Excel + Sheets', desc: 'Import .xlsx, .csv, or connect Google Sheets. Auto-validate, dedupe, suppress.' },
              { icon: '🎨', title: 'HTML editor', desc: 'Paste your HTML. Live desktop + mobile preview. Plain-text fallback auto-generated.' },
              { icon: '🛡️', title: 'Suppression list', desc: 'One-click unsubscribe headers. Bounces, complaints, manual blocks — all respected.' },
              { icon: '🔄', title: 'Crash-safe queue', desc: 'Redis + BullMQ with idempotency. Restart anywhere without duplicate sends.' },
            ].map((f, i) => (
              <div key={f.title} className={`tilt card animate-in-slow delay-${(i % 5) + 1}`}>
                <div className="text-3xl mb-4 floaty" style={{ animationDelay: `${i * 0.4}s` }}>{f.icon}</div>
                <h3 className="font-semibold text-lg mb-2">{f.title}</h3>
                <p className="text-sm text-slate-400 leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="relative py-32 px-6">
        <div className="max-w-3xl mx-auto text-center relative z-10">
          <h2 className="text-4xl md:text-6xl font-semibold tracking-tight mb-8">
            Ready to send?
          </h2>
          <p className="text-slate-400 mb-12 text-lg">
            Connect your Gmail. Import contacts. Watch it go.
          </p>
          <Link href="/login" className="btn btn-primary text-base px-8 py-3.5">
            Start free →
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-white/5 py-10 px-6">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-slate-500">
          <div>© {new Date().getFullYear()} EmailCampaign</div>
          <div className="flex gap-6">
            <a href="https://github.com/dipenzala/emailcampaign" className="hover:text-white transition">GitHub</a>
            <Link href="/login" className="hover:text-white transition">Sign in</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
