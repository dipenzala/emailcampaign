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
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-[1.02] animate-in-slow">
            Send email<br /><span className="gradient-text">that feels personal.</span>
          </h1>
          <p className="mt-8 text-lg md:text-xl text-slate-400 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            Production-ready campaign platform. Import contacts, paste HTML, hit send.
          </p>
          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-7 py-3">Start free →</Link>
          </div>
        </div>
      </section>
      <footer className="relative border-t border-white/5 py-10 px-6 text-sm text-slate-500">
        <div className="max-w-6xl mx-auto text-center">© {new Date().getFullYear()} EmailCampaign</div>
      </footer>
    </div>
  );
}
