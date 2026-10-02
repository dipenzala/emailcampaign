#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🚀 EmailCampaign — Master Deploy (UI + Fix + Push)"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ package.json nahi mila."; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF fix ----------
echo ""
echo "🔧 Line endings fix..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅ Done"

# ---------- 2. Prisma schema ----------
echo ""
echo "📝 prisma/schema.prisma..."
mkdir -p prisma
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
}

model SenderAccount {
  id            String   @id @default(cuid())
  email         String   @unique
  displayName   String?
  accessToken   String?
  refreshToken  String?
  tokenExpiry   DateTime?
  scope         String?
  status        String   @default("DISCONNECTED")
  sentToday     Int      @default(0)
  errors        Int      @default(0)
  lastSuccessAt DateTime?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}

model Contact {
  id         String   @id @default(cuid())
  email      String   @unique
  name       String?
  company    String?
  phone      String?
  city       String?
  custom     Json?
  createdAt  DateTime @default(now())
  recipients CampaignRecipient[]
}

model SuppressionList {
  id        String   @id @default(cuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}

model Campaign {
  id              String   @id @default(cuid())
  name            String
  subject         String
  html            String
  status          String   @default("DRAFT")
  totalCount      Int      @default(0)
  sentCount       Int      @default(0)
  deliveredCount  Int      @default(0)
  failedCount     Int      @default(0)
  bouncedCount    Int      @default(0)
  suppressedCount Int      @default(0)
  createdAt       DateTime @default(now())
  startedAt       DateTime?
  completedAt     DateTime?
  recipients      CampaignRecipient[]
}

model CampaignRecipient {
  id                String   @id @default(cuid())
  campaignId        String
  contactId         String
  senderAccountId   String?
  status            String   @default("QUEUED")
  providerMessageId String?
  errorCode         String?
  errorMessage      String?
  attemptCount      Int      @default(0)
  queuedAt          DateTime @default(now())
  sentAt            DateTime?
  deliveredAt       DateTime?
  failedAt          DateTime?
  campaign          Campaign @relation(fields: [campaignId], references: [id], onDelete: Cascade)
  contact           Contact  @relation(fields: [contactId], references: [id])

  @@unique([campaignId, contactId])
  @@index([campaignId, status])
}

model MessageLog {
  id          String   @id @default(cuid())
  campaignId  String
  recipientId String
  level       String
  message     String
  createdAt   DateTime @default(now())
}

model AuditLog {
  id        String   @id @default(cuid())
  action    String
  meta      Json?
  createdAt DateTime @default(now())
}
PRISMA
sed -i 's/\r$//' prisma/schema.prisma
echo "✅ schema written"

# ---------- 3. package.json fix ----------
echo ""
echo "📦 package.json..."
node -e '
const fs=require("fs");
const pkg=JSON.parse(fs.readFileSync("package.json","utf8"));
pkg.dependencies=pkg.dependencies||{};
pkg.devDependencies=pkg.devDependencies||{};
["tsx","typescript","prisma"].forEach(p=>{
  if(pkg.devDependencies[p]){pkg.dependencies[p]=pkg.devDependencies[p];delete pkg.devDependencies[p];}
});
fs.writeFileSync("package.json",JSON.stringify(pkg,null,2));
console.log("   ✅ Fixed");
'
echo "✅ package.json updated"

# ---------- 4. Procfile + gitattributes + gitignore ----------
echo ""
echo "worker: npm run worker" > Procfile
sed -i 's/\r$//' Procfile

cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
Procfile text eol=lf
*.prisma text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.json text eol=lf
*.css text eol=lf
EOF
sed -i 's/\r$//' .gitattributes

if [ ! -f ".gitignore" ] || ! grep -q node_modules .gitignore; then
cat > .gitignore <<'EOF'
node_modules/
.next/
out/
build/
dist/
.env
.env.local
.env*.local
.env.production
*.db
*.log
.vscode/
.idea/
.DS_Store
.vercel
next-env.d.ts
EOF
sed -i 's/\r$//' .gitignore
fi
echo "✅ Procfile + .gitattributes + .gitignore ready"

# ---------- 5. Move existing dashboard ----------
echo ""
echo "📂 Moving dashboard to /dashboard..."
mkdir -p app/dashboard
if [ -f "app/page.tsx" ] && [ ! -f "app/dashboard/page.tsx" ]; then
  mv app/page.tsx app/dashboard/page.tsx
  echo "✅ Moved page.tsx → dashboard/page.tsx"
fi
# Old dashboard links stay valid; only '/' root is replaced.

# ---------- 6. Session lib ----------
echo ""
echo "🔐 lib/session.ts..."
cat > lib/session.ts <<'EOF'
import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export function signSession(payload: { email: string; name?: string; ts: number }) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): { email: string; name?: string } | null {
  if (!token) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try {
    return JSON.parse(Buffer.from(data, 'base64url').toString());
  } catch {
    return null;
  }
}
EOF
sed -i 's/\r$//' lib/session.ts
echo "✅ session helper"

# ---------- 7. Auth API ----------
echo ""
echo "🔐 Auth API routes..."
mkdir -p app/api/auth/login app/api/auth/logout app/api/auth/me

cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';

export async function POST(req: Request) {
  const { email, name } = await req.json();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  }
  const cleanEmail = String(email).toLowerCase().trim();
  await prisma.user.upsert({
    where: { email: cleanEmail },
    create: { email: cleanEmail, name: name || cleanEmail.split('@')[0] },
    update: { name: name || undefined },
  }).catch(() => {});

  const token = signSession({ email: cleanEmail, name: name || cleanEmail.split('@')[0], ts: Date.now() });
  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
EOF

cat > app/api/auth/logout/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
  return res;
}
EOF

cat > app/api/auth/me/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifySession } from '@/lib/session';
export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const user = verifySession(token);
  if (!user) return NextResponse.json({ user: null }, { status: 401 });
  return NextResponse.json({ user: { email: user.email, name: user.name } });
}
EOF
sed -i 's/\r$//' app/api/auth/login/route.ts app/api/auth/logout/route.ts app/api/auth/me/route.ts
echo "✅ Auth API ready"

# ---------- 8. Middleware ----------
echo ""
echo "🛡️  middleware.ts..."
cat > middleware.ts <<'EOF'
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  const token = req.cookies.get('ec_session')?.value;
  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', req.nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/senders/:path*', '/history/:path*', '/campaigns/:path*'],
};
EOF
sed -i 's/\r$//' middleware.ts
echo "✅ middleware ready"

# ---------- 9. globals.css — animations ----------
echo ""
echo "🎨 globals.css (Apple-style animations)..."
cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --bg: #05060a;
  --fg: #f5f7fa;
}

* { -webkit-tap-highlight-color: transparent; }

html, body {
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Inter, sans-serif;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
  scroll-behavior: smooth;
}

/* ---------- Reusable ---------- */
.card { @apply bg-slate-900/60 backdrop-blur border border-slate-800/60 rounded-2xl p-6; }
.btn { @apply inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-medium transition-all duration-300 select-none; }
.btn-primary { @apply bg-white text-black hover:bg-slate-200 shadow-lg shadow-white/10; }
.btn-ghost { @apply bg-white/5 hover:bg-white/10 text-white border border-white/10 backdrop-blur; }
.btn-danger { @apply bg-red-500/90 hover:bg-red-500 text-white; }
.input {
  @apply w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5
         text-white placeholder-slate-500 focus:outline-none focus:border-white/30
         focus:bg-white/[0.07] transition-all duration-200;
}

/* ---------- Gradient text ---------- */
.gradient-text {
  background: linear-gradient(120deg, #a78bfa 0%, #60a5fa 30%, #34d399 60%, #f472b6 100%);
  background-size: 300% 300%;
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  animation: gradientShift 8s ease infinite;
}
@keyframes gradientShift {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

/* ---------- Aurora / mesh background ---------- */
.aurora {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
  z-index: 0;
}
.aurora::before,
.aurora::after {
  content: '';
  position: absolute;
  width: 60vw;
  height: 60vw;
  border-radius: 50%;
  filter: blur(120px);
  opacity: 0.35;
}
.aurora::before {
  background: radial-gradient(circle, #6366f1, transparent 65%);
  top: -20%;
  left: -10%;
  animation: float1 18s ease-in-out infinite;
}
.aurora::after {
  background: radial-gradient(circle, #ec4899, transparent 65%);
  bottom: -30%;
  right: -10%;
  animation: float2 22s ease-in-out infinite;
}
@keyframes float1 {
  0%, 100% { transform: translate3d(0,0,0) scale(1); }
  50% { transform: translate3d(8vw, 6vh, 0) scale(1.15); }
}
@keyframes float2 {
  0%, 100% { transform: translate3d(0,0,0) scale(1.1); }
  50% { transform: translate3d(-10vw, -8vh, 0) scale(0.95); }
}

/* ---------- Fade/slide in on load ---------- */
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(0); }
}
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
.animate-in { animation: fadeInUp 0.9s cubic-bezier(0.22, 1, 0.36, 1) both; }
.animate-in-slow { animation: fadeInUp 1.3s cubic-bezier(0.22, 1, 0.36, 1) both; }
.animate-fade { animation: fadeIn 1.4s ease both; }
.delay-1 { animation-delay: 0.15s; }
.delay-2 { animation-delay: 0.30s; }
.delay-3 { animation-delay: 0.45s; }
.delay-4 { animation-delay: 0.60s; }
.delay-5 { animation-delay: 0.75s; }

/* ---------- Glass nav ---------- */
.glass-nav {
  background: rgba(5, 6, 10, 0.6);
  backdrop-filter: saturate(180%) blur(18px);
  -webkit-backdrop-filter: saturate(180%) blur(18px);
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

/* ---------- Tilt cards (3D) ---------- */
.tilt {
  transition: transform 0.5s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.5s ease;
  transform-style: preserve-3d;
  will-change: transform;
}
.tilt:hover {
  transform: perspective(1200px) rotateX(4deg) rotateY(-4deg) translateY(-6px) scale(1.02);
  box-shadow: 0 30px 60px -20px rgba(99,102,241,0.35), 0 0 0 1px rgba(255,255,255,0.05);
}

/* ---------- Shimmer badge ---------- */
.shimmer {
  position: relative;
  overflow: hidden;
}
.shimmer::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(255,255,255,0.35) 50%, transparent 70%);
  transform: translateX(-100%);
  animation: shimmer 3s ease-in-out infinite;
}
@keyframes shimmer {
  0% { transform: translateX(-100%); }
  60%, 100% { transform: translateX(100%); }
}

/* ---------- Floating ---------- */
@keyframes floaty {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-12px); }
}
.floaty { animation: floaty 6s ease-in-out infinite; }

/* ---------- Scrollbar (dashboard) ---------- */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.12); border-radius: 8px; }
::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.22); }
EOF
sed -i 's/\r$//' app/globals.css
echo "✅ globals.css"

# ---------- 10. Layout ----------
echo ""
echo "🎨 app/layout.tsx..."
cat > app/layout.tsx <<'EOF'
import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'EmailCampaign — Send beautifully',
  description: 'A modern email campaign platform. Gmail OAuth, real-time dashboard, zero spam.',
};

export default function Root({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
EOF
sed -i 's/\r$//' app/layout.tsx
echo "✅ layout"

# ---------- 11. Landing page ----------
echo ""
echo "✨ app/page.tsx (landing)..."
cat > app/page.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' app/page.tsx
echo "✅ Landing page ready"

# ---------- 12. Login page ----------
echo ""
echo "🔐 app/login/page.tsx..."
mkdir -p app/login
cat > app/login/page.tsx <<'EOF'
'use client';
import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';

  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      const r = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, name }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next);
      router.refresh();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />

      <div className="relative z-10 w-full max-w-md">
        <Link href="/" className="inline-flex items-center gap-2 mb-8 text-sm text-slate-400 hover:text-white transition">
          ← Back to home
        </Link>

        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty" />
            <h1 className="text-2xl font-semibold tracking-tight">Welcome back</h1>
            <p className="text-sm text-slate-400 mt-2">Sign in to launch your campaign</p>
          </div>

          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Email</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@company.com"
                className="input"
                autoComplete="email"
              />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Name (optional)</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Your name"
                className="input"
                autoComplete="name"
              />
            </div>

            {err && (
              <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {err}
              </div>
            )}

            <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">
              {busy ? 'Signing in…' : 'Continue →'}
            </button>
          </form>

          <div className="mt-6 text-xs text-slate-500 text-center leading-relaxed">
            By continuing you agree to send email responsibly.
            <br />
            Gmail OAuth connections are managed separately in the Senders panel.
          </div>
        </div>

        <p className="text-xs text-slate-500 text-center mt-6">
          First time? Just enter your email — account auto-creates.
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
EOF
sed -i 's/\r$//' app/login/page.tsx
echo "✅ Login page ready"

# ---------- 13. Dashboard wrapper (adds nav + logout) ----------
echo ""
echo "🎛️  app/dashboard/layout.tsx..."
cat > app/dashboard/layout.tsx <<'EOF'
import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { verifySession } from '@/lib/session';
import LogoutButton from './logout-button';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) redirect('/login');

  return (
    <div className="min-h-screen">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-6 py-3 flex items-center justify-between">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
            <span className="font-semibold tracking-tight text-sm">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-1">
            <Link href="/dashboard" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Campaign</Link>
            <Link href="/senders" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Senders</Link>
            <Link href="/history" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">History</Link>
            <div className="w-px h-5 bg-white/10 mx-2" />
            <span className="text-xs text-slate-500 hidden md:inline">{session.email}</span>
            <LogoutButton />
          </div>
        </div>
      </nav>
      <main className="max-w-6xl mx-auto px-6 py-8">{children}</main>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/layout.tsx

cat > app/dashboard/logout-button.tsx <<'EOF'
'use client';
import { useRouter } from 'next/navigation';
export default function LogoutButton() {
  const router = useRouter();
  const out = async () => {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/');
    router.refresh();
  };
  return (
    <button onClick={out} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">
      Sign out
    </button>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/logout-button.tsx
echo "✅ Dashboard layout + logout"

# ---------- 14. Update senders/history to use new layout (create shared layout) ----------
echo ""
echo "🎛️  app/(app)/layout.tsx → shared layout for /senders, /history, /campaigns..."
mkdir -p 'app/(app)'
cat > 'app/(app)/layout.tsx' <<'EOF'
export default function AppGroupLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
EOF
sed -i 's/\r$//' 'app/(app)/layout.tsx'

# ---------- 15. Prisma validate ----------
echo ""
echo "🔎 Validating Prisma schema..."
if npx --yes prisma validate >/tmp/pv.log 2>&1; then
  echo "✅ Prisma schema valid"
else
  echo "❌ Prisma validation failed:"
  cat /tmp/pv.log
  exit 1
fi

# ---------- 16. Git commit + push ----------
echo ""
echo "🌿 Git setup..."
if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  git rm --cached .env >/dev/null 2>&1 || true
fi
echo "✅ Remote: $(git remote get-url origin)"

git add -A
if git diff --cached --quiet; then
  echo "ℹ️  Kuch naya nahi."
else
  git -c user.email="$(git config user.email || echo deploy@local)" \
      -c user.name="$(git config user.name || echo Deploy)" \
      commit -m "UI: Apple-style landing + login + protected dashboard"
  echo "✅ Committed"
fi

echo ""
echo "🚀 Pushing..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ Sab complete!"
echo "==================================================="
echo ""
echo "📊 Vercel auto-deploy trigger ho gaya:"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "🎯 Test URLs (deploy ke baad):"
echo "   /          → Landing"
echo "   /login     → Login"
echo "   /dashboard → Campaign dashboard (protected)"
echo "   /senders   → Senders (protected)"
echo "==================================================="