import Link from 'next/link';
export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      <div className="aurora" aria-hidden />
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
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
      <section className="relative pt-40 pb-32 px-6">
        <div className="max-w-5xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs text-slate-300 mb-8 animate-in shimmer">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            Powered by Gmail API · OAuth 2.0
          </div>
          <h1 className="text-5xl md:text-7xl lg:text-8xl font-semibold tracking-tight leading-[1.02] animate-in-slow delay-1">
            Send email<br /><span className="gradient-text">that feels personal.</span>
          </h1>
          <p className="mt-8 text-lg md:text-xl text-slate-400 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            Production-ready campaign platform. Import contacts, paste HTML, hit send — watch it fly.
          </p>
          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-7 py-3">Start a campaign →</Link>
            <a href="#features" className="btn btn-ghost text-base px-7 py-3">See features</a>
          </div>
        </div>
        <div className="relative max-w-4xl mx-auto mt-24 animate-in-slow delay-5">
          <div className="tilt card !p-0 overflow-hidden shadow-2xl shadow-violet-500/10">
            <div className="flex items-center gap-2 px-4 py-3 border-b border-white/5 bg-white/[0.02]">
              <span className="w-3 h-3 rounded-full bg-red-400/70" />
              <span className="w-3 h-3 rounded-full bg-yellow-400/70" />
              <span className="w-3 h-3 rounded-full bg-green-400/70" />
              <span className="ml-3 text-xs text-slate-500">campaign · live</span>
            </div>
            <div className="p-8 grid grid-cols-2 md:grid-cols-4 gap-4">
              {[['SENT','12,847','text-blue-400'],['DELIVERED','12,412','text-emerald-400'],['PENDING','435','text-amber-400'],['FAILED','12','text-red-400']].map(([l,v,c]) => (
                <div key={l} className="bg-white/[0.03] border border-white/5 rounded-xl p-4">
                  <div className="text-[10px] tracking-widest text-slate-500">{l}</div>
                  <div className={`text-2xl font-semibold mt-1 ${c}`}>{v}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
      <section id="features" className="relative py-32 px-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-20">
            <h2 className="text-4xl md:text-5xl font-semibold tracking-tight">Everything you need. <span className="gradient-text">Nothing you don't.</span></h2>
          </div>
          <div className="grid md:grid-cols-3 gap-6">
            {[
              ['🔒','OAuth 2.0 only','Never see your Gmail password. AES-256 encryption.'],
              ['⚡','Real-time dashboard','Server-sent events stream live counters.'],
              ['📊','Excel + Sheets','Import .xlsx, .csv. Auto-validate + dedupe.'],
              ['🎨','HTML editor','Paste HTML. Live preview. Text fallback.'],
              ['🛡️','7-layer anti-spam','Spam checker, warm-up, bounce handler, and more.'],
              ['🔄','Crash-safe queue','Redis + BullMQ with idempotency.'],
            ].map(([i,t,d],idx) => (
              <div key={t} className={`tilt card animate-in-slow delay-${(idx%5)+1}`}>
                <div className="text-3xl mb-4 floaty" style={{animationDelay:`${idx*.4}s`}}>{i}</div>
                <h3 className="font-semibold text-lg mb-2">{t}</h3>
                <p className="text-sm text-slate-400 leading-relaxed">{d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="relative py-32 px-6 text-center">
        <h2 className="text-4xl md:text-6xl font-semibold tracking-tight mb-8 relative z-10">Ready to send?</h2>
        <Link href="/login" className="btn btn-primary text-base px-8 py-3.5 relative z-10">Start free →</Link>
      </section>
      <footer className="relative border-t border-white/5 py-12 px-6">
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
      </footer>
    </div>
  );
}
