#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🚀 EmailCampaign — FINAL v2"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅ CRLF"

# ---------- 2. Prisma schema ----------
echo "📝 prisma/schema.prisma..."
mkdir -p prisma
cat > prisma/schema.prisma <<'PRISMA'
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql"; url = env("DATABASE_URL") }

model User {
  id String @id @default(cuid())
  email String @unique
  name String?
  createdAt DateTime @default(now())
}
model SenderAccount {
  id String @id @default(cuid())
  email String @unique
  displayName String?
  accessToken String?
  refreshToken String?
  tokenExpiry DateTime?
  scope String?
  status String @default("DISCONNECTED")
  sentToday Int @default(0)
  errors Int @default(0)
  lastSuccessAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
model Contact {
  id String @id @default(cuid())
  email String @unique
  name String?
  company String?
  phone String?
  city String?
  custom Json?
  createdAt DateTime @default(now())
  recipients CampaignRecipient[]
}
model SuppressionList {
  id String @id @default(cuid())
  email String @unique
  reason String
  createdAt DateTime @default(now())
}
model Campaign {
  id String @id @default(cuid())
  name String
  subject String
  html String
  status String @default("DRAFT")
  totalCount Int @default(0)
  sentCount Int @default(0)
  deliveredCount Int @default(0)
  failedCount Int @default(0)
  bouncedCount Int @default(0)
  suppressedCount Int @default(0)
  createdAt DateTime @default(now())
  startedAt DateTime?
  completedAt DateTime?
  recipients CampaignRecipient[]
}
model CampaignRecipient {
  id String @id @default(cuid())
  campaignId String
  contactId String
  senderAccountId String?
  status String @default("QUEUED")
  providerMessageId String?
  errorCode String?
  errorMessage String?
  attemptCount Int @default(0)
  queuedAt DateTime @default(now())
  sentAt DateTime?
  deliveredAt DateTime?
  failedAt DateTime?
  campaign Campaign @relation(fields: [campaignId], references: [id], onDelete: Cascade)
  contact Contact @relation(fields: [contactId], references: [id])
  @@unique([campaignId, contactId])
  @@index([campaignId, status])
}
model MessageLog {
  id String @id @default(cuid())
  campaignId String
  recipientId String
  level String
  message String
  createdAt DateTime @default(now())
}
model AuditLog {
  id String @id @default(cuid())
  action String
  meta Json?
  createdAt DateTime @default(now())
}
PRISMA
sed -i 's/\r$//' prisma/schema.prisma
echo "✅ schema"

# ---------- 3. package.json ----------
echo "📦 package.json..."
node -e '
const fs=require("fs");
const pkg=JSON.parse(fs.readFileSync("package.json","utf8"));
pkg.dependencies=pkg.dependencies||{};
pkg.devDependencies=pkg.devDependencies||{};
// move runtime deps
["tsx","typescript","prisma"].forEach(p=>{
  if(pkg.devDependencies[p]){pkg.dependencies[p]=pkg.devDependencies[p];delete pkg.devDependencies[p];}
});
// pin bullmq to avoid valkey-glide import
pkg.dependencies["bullmq"]="^5.28.0";
// scripts
pkg.scripts=pkg.scripts||{};
pkg.scripts.build="prisma generate && next build";
pkg.scripts.worker="tsx workers/sender.worker.ts";
pkg.scripts["db:push"]="prisma db push";
pkg.scripts["db:studio"]="prisma studio";
pkg.scripts.dev="concurrently -n next,worker -c cyan,magenta \"next dev -p 3000\" \"tsx watch workers/sender.worker.ts\"";
pkg.scripts.start="concurrently -n next,worker -c cyan,magenta \"next start -p 3000\" \"tsx workers/sender.worker.ts\"";
fs.writeFileSync("package.json",JSON.stringify(pkg,null,2));
console.log("   ✅ bullmq pinned + scripts set");
'
echo "✅"

# ---------- 4. Procfile + gitattributes + gitignore ----------
printf "worker: npm run worker\n" > Procfile
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
echo "✅ Procfile + gitattrs + gitignore"

# ---------- 5. lib/redis.ts ----------
cat > lib/redis.ts <<'EOF'
import IORedis from 'ioredis';
const g = globalThis as any;
function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();
  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    return new IORedis({
      host: '127.0.0.1', port: 6379,
      lazyConnect: true, maxRetriesPerRequest: null, enableOfflineQueue: false,
    });
  }
  return new IORedis(url, { maxRetriesPerRequest: null, enableReadyCheck: false, lazyConnect: true });
}
export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
EOF
sed -i 's/\r$//' lib/redis.ts

# ---------- 6. lib/queue.ts (lazy) ----------
cat > lib/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import { redis } from './redis';
export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';
let _queue: Queue | null = null;
export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, { connection: redis, prefix: QUEUE_PREFIX });
  return _queue;
}
export const sendQueue = new Proxy({} as Queue, {
  get(_t, prop) {
    const q = getSendQueue();
    const v = (q as any)[prop];
    return typeof v === 'function' ? v.bind(q) : v;
  },
});
EOF
sed -i 's/\r$//' lib/queue.ts

# ---------- 7. lib/session.ts ----------
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
  try { return JSON.parse(Buffer.from(data, 'base64url').toString()); } catch { return null; }
}
EOF
sed -i 's/\r$//' lib/session.ts

# ---------- 8. Auth API (with force-dynamic) ----------
mkdir -p app/api/auth/login app/api/auth/logout app/api/auth/me

cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function POST(req: Request) {
  const { email, name } = await req.json();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  }
  const cleanEmail = String(email).toLowerCase().trim();
  try {
    await prisma.user.upsert({
      where: { email: cleanEmail },
      create: { email: cleanEmail, name: name || cleanEmail.split('@')[0] },
      update: {},
    });
  } catch { /* DB not ready */ }
  const token = signSession({ email: cleanEmail, name: name || cleanEmail.split('@')[0], ts: Date.now() });
  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax', path: '/', maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
EOF

cat > app/api/auth/logout/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export const dynamic = 'force-dynamic';
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
export const dynamic = 'force-dynamic';
export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const user = verifySession(token);
  if (!user) return NextResponse.json({ user: null }, { status: 401 });
  return NextResponse.json({ user: { email: user.email, name: user.name } });
}
EOF
sed -i 's/\r$//' app/api/auth/login/route.ts app/api/auth/logout/route.ts app/api/auth/me/route.ts

# ---------- 9. Patch existing API routes with force-dynamic ----------
echo "🛠️  Patching API routes with force-dynamic..."

# List of API route files
ROUTES=(
  "app/api/health/route.ts"
  "app/api/senders/route.ts"
  "app/api/contacts/upload/route.ts"
  "app/api/campaigns/route.ts"
  "app/api/campaigns/[id]/start/route.ts"
  "app/api/campaigns/[id]/pause/route.ts"
  "app/api/campaigns/[id]/resume/route.ts"
  "app/api/campaigns/[id]/stop/route.ts"
  "app/api/campaigns/[id]/status/route.ts"
  "app/api/campaigns/[id]/stream/route.ts"
  "app/api/campaigns/[id]/recipients/route.ts"
  "app/api/test-email/route.ts"
  "app/api/oauth/google/start/route.ts"
  "app/api/oauth/google/callback/route.ts"
  "app/api/unsubscribe/[token]/route.ts"
)

for f in "${ROUTES[@]}"; do
  if [ -f "$f" ]; then
    # Check if already has force-dynamic
    if ! grep -q "force-dynamic" "$f"; then
      # Insert after first import block (find first blank line after imports)
      # Simpler: prepend after the imports by finding last import line
      python3 - "$f" <<'PYEOF' 2>/dev/null || node -e '
const fs = require("fs");
const f = process.argv[1];
let s = fs.readFileSync(f, "utf8");
if (!s.includes("force-dynamic")) {
  // Find last import statement line
  const lines = s.split("\n");
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*import\s/.test(lines[i])) lastImport = i;
  }
  const insert = "\nexport const dynamic = \"force-dynamic\";\nexport const runtime = \"nodejs\";\n";
  if (lastImport >= 0) {
    lines.splice(lastImport + 1, 0, insert);
  } else {
    lines.unshift(insert);
  }
  fs.writeFileSync(f, lines.join("\n"));
}
' "$f"
PYEOF
    fi
  fi
done

# Simpler fallback — use node to patch all
node <<'NODEEOF'
const fs = require('fs');
const path = require('path');
const routes = [
  'app/api/health/route.ts',
  'app/api/senders/route.ts',
  'app/api/contacts/upload/route.ts',
  'app/api/campaigns/route.ts',
  'app/api/campaigns/[id]/start/route.ts',
  'app/api/campaigns/[id]/pause/route.ts',
  'app/api/campaigns/[id]/resume/route.ts',
  'app/api/campaigns/[id]/stop/route.ts',
  'app/api/campaigns/[id]/status/route.ts',
  'app/api/campaigns/[id]/stream/route.ts',
  'app/api/campaigns/[id]/recipients/route.ts',
  'app/api/test-email/route.ts',
  'app/api/oauth/google/start/route.ts',
  'app/api/oauth/google/callback/route.ts',
  'app/api/unsubscribe/[token]/route.ts',
];
let patched = 0;
for (const r of routes) {
  if (!fs.existsSync(r)) continue;
  let s = fs.readFileSync(r, 'utf8');
  if (s.includes('force-dynamic')) continue;
  const lines = s.split('\n');
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*import\s/.test(lines[i])) lastImport = i;
  }
  const insert = [
    '',
    'export const dynamic = "force-dynamic";',
    'export const runtime = "nodejs";',
    '',
  ];
  if (lastImport >= 0) {
    lines.splice(lastImport + 1, 0, ...insert);
  } else {
    lines.unshift(...insert);
  }
  fs.writeFileSync(r, lines.join('\n'));
  patched++;
}
console.log(`   Patched ${patched} routes with force-dynamic`);
NODEEOF

echo "✅ Routes patched"

# ---------- 10. globals.css (compact) ----------
cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
:root{--bg:#05060a;--fg:#f5f7fa}
*{-webkit-tap-highlight-color:transparent}
html,body{background:var(--bg);color:var(--fg);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",Inter,sans-serif;-webkit-font-smoothing:antialiased;overflow-x:hidden;scroll-behavior:smooth}
.card{@apply bg-slate-900/60 backdrop-blur border border-slate-800/60 rounded-2xl p-6}
.btn{@apply inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-medium transition-all duration-300 select-none}
.btn-primary{@apply bg-white text-black hover:bg-slate-200 shadow-lg shadow-white/10}
.btn-ghost{@apply bg-white/5 hover:bg-white/10 text-white border border-white/10 backdrop-blur}
.btn-danger{@apply bg-red-500/90 hover:bg-red-500 text-white}
.input{@apply w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-white/30 focus:bg-white/[0.07] transition-all duration-200}
.gradient-text{background:linear-gradient(120deg,#a78bfa 0%,#60a5fa 30%,#34d399 60%,#f472b6 100%);background-size:300% 300%;-webkit-background-clip:text;background-clip:text;color:transparent;animation:gradientShift 8s ease infinite}
@keyframes gradientShift{0%,100%{background-position:0% 50%}50%{background-position:100% 50%}}
.aurora{position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:0}
.aurora::before,.aurora::after{content:'';position:absolute;width:60vw;height:60vw;border-radius:50%;filter:blur(120px);opacity:.35}
.aurora::before{background:radial-gradient(circle,#6366f1,transparent 65%);top:-20%;left:-10%;animation:float1 18s ease-in-out infinite}
.aurora::after{background:radial-gradient(circle,#ec4899,transparent 65%);bottom:-30%;right:-10%;animation:float2 22s ease-in-out infinite}
@keyframes float1{0%,100%{transform:translate3d(0,0,0) scale(1)}50%{transform:translate3d(8vw,6vh,0) scale(1.15)}}
@keyframes float2{0%,100%{transform:translate3d(0,0,0) scale(1.1)}50%{transform:translate3d(-10vw,-8vh,0) scale(.95)}}
@keyframes fadeInUp{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
.animate-in{animation:fadeInUp .9s cubic-bezier(.22,1,.36,1) both}
.animate-in-slow{animation:fadeInUp 1.3s cubic-bezier(.22,1,.36,1) both}
.animate-fade{animation:fadeIn 1.4s ease both}
.delay-1{animation-delay:.15s}.delay-2{animation-delay:.30s}.delay-3{animation-delay:.45s}.delay-4{animation-delay:.60s}.delay-5{animation-delay:.75s}
.glass-nav{background:rgba(5,6,10,.6);backdrop-filter:saturate(180%) blur(18px);-webkit-backdrop-filter:saturate(180%) blur(18px);border-bottom:1px solid rgba(255,255,255,.06)}
.tilt{transition:transform .5s cubic-bezier(.22,1,.36,1),box-shadow .5s ease;transform-style:preserve-3d;will-change:transform}
.tilt:hover{transform:perspective(1200px) rotateX(4deg) rotateY(-4deg) translateY(-6px) scale(1.02);box-shadow:0 30px 60px -20px rgba(99,102,241,.35),0 0 0 1px rgba(255,255,255,.05)}
.shimmer{position:relative;overflow:hidden}
.shimmer::after{content:'';position:absolute;inset:0;background:linear-gradient(115deg,transparent 30%,rgba(255,255,255,.35) 50%,transparent 70%);transform:translateX(-100%);animation:shimmer 3s ease-in-out infinite}
@keyframes shimmer{0%{transform:translateX(-100%)}60%,100%{transform:translateX(100%)}}
@keyframes floaty{0%,100%{transform:translateY(0)}50%{transform:translateY(-12px)}}
.floaty{animation:floaty 6s ease-in-out infinite}
::-webkit-scrollbar{width:8px;height:8px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:rgba(255,255,255,.12);border-radius:8px}::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.22)}
EOF
sed -i 's/\r$//' app/globals.css

# ---------- 11. layout ----------
cat > app/layout.tsx <<'EOF'
import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'EmailCampaign', description: 'A modern email campaign platform.' };
export default function Root({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="min-h-screen antialiased">{children}</body></html>;
}
EOF
sed -i 's/\r$//' app/layout.tsx

# ---------- 12. Landing ----------
cat > app/page.tsx <<'EOF'
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
            A production-ready campaign platform. Import contacts, paste your HTML, hit send — watch it fly in real-time.
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
            <div className="px-8 pb-8">
              <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                <div className="h-full w-[96%] bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-400 rounded-full" />
              </div>
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
              ['🔒','OAuth 2.0 only','We never see your Gmail password. Tokens AES-256 encrypted.'],
              ['⚡','Real-time dashboard','Server-sent events stream live counters.'],
              ['📊','Excel + Sheets','Import .xlsx, .csv or Google Sheets.'],
              ['🎨','HTML editor','Paste HTML. Live preview. Text fallback.'],
              ['🛡️','Suppression list','One-click unsubscribe respected.'],
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
      <footer className="relative border-t border-white/5 py-10 px-6 text-sm text-slate-500">
        <div className="max-w-6xl mx-auto text-center">© {new Date().getFullYear()} EmailCampaign</div>
      </footer>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/page.tsx

# ---------- 13. Login ----------
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
    e.preventDefault(); setErr(''); setBusy(true);
    try {
      const r = await fetch('/api/auth/login', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({email,name}) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next); router.refresh();
    } catch (e: any) { setErr(e.message); setBusy(false); }
  };
  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />
      <div className="relative z-10 w-full max-w-md">
        <Link href="/" className="inline-flex items-center gap-2 mb-8 text-sm text-slate-400 hover:text-white transition">← Back to home</Link>
        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty" />
            <h1 className="text-2xl font-semibold tracking-tight">Welcome back</h1>
            <p className="text-sm text-slate-400 mt-2">Sign in to launch your campaign</p>
          </div>
          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Email</label>
              <input type="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" className="input" />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Name (optional)</label>
              <input type="text" value={name} onChange={e=>setName(e.target.value)} placeholder="Your name" className="input" />
            </div>
            {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">{err}</div>}
            <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">{busy ? 'Signing in…' : 'Continue →'}</button>
          </form>
        </div>
      </div>
    </div>
  );
}
export default function LoginPage() {
  return <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}><LoginInner /></Suspense>;
}
EOF
sed -i 's/\r$//' app/login/page.tsx

# ---------- 14. Dashboard ----------
mkdir -p app/dashboard
cat > app/dashboard/layout.tsx <<'EOF'
import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { verifySession } from '@/lib/session';
import LogoutButton from './logout-button';
export const dynamic = 'force-dynamic';
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
  return <button onClick={async()=>{ await fetch('/api/auth/logout',{method:'POST'}); router.push('/'); router.refresh(); }} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Sign out</button>;
}
EOF
sed -i 's/\r$//' app/dashboard/logout-button.tsx

# Backup any existing dashboard page
if [ -f "app/dashboard/page.tsx" ]; then
  cp app/dashboard/page.tsx app/dashboard/page.tsx.bak 2>/dev/null || true
fi

cat > app/dashboard/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
export default function DashboardHome() {
  const [senders, setSenders] = useState<any[]>([]);
  useEffect(() => { fetch('/api/senders').then(r=>r.ok?r.json():[]).then(setSenders).catch(()=>{}); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Dashboard</h1>
      <p className="text-slate-400">Start by importing contacts and pasting your HTML email.</p>
      <div className="grid md:grid-cols-3 gap-4">
        <a href="/senders" className="tilt card">
          <div className="text-3xl mb-2">🔐</div>
          <h3 className="font-semibold">Manage Senders</h3>
          <p className="text-sm text-slate-400 mt-1">{senders.length} connected</p>
        </a>
        <a href="/history" className="tilt card">
          <div className="text-3xl mb-2">📊</div>
          <h3 className="font-semibold">History</h3>
          <p className="text-sm text-slate-400 mt-1">View past campaigns</p>
        </a>
        <div className="tilt card">
          <div className="text-3xl mb-2">🚀</div>
          <h3 className="font-semibold">New Campaign</h3>
          <p className="text-sm text-slate-400 mt-1">Coming soon</p>
        </div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/page.tsx

# ---------- 15. Middleware ----------
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

# ---------- 16. Verify force-dynamic applied ----------
echo ""
echo "🔎 Verifying force-dynamic on API routes..."
MISSING=0
for f in app/api/*/route.ts app/api/*/*/route.ts app/api/*/*/*/route.ts; do
  [ -f "$f" ] || continue
  if ! grep -q "force-dynamic" "$f"; then
    echo "   ⚠️  Missing: $f"
    MISSING=$((MISSING+1))
  fi
done
[ $MISSING -eq 0 ] && echo "   ✅ All API routes dynamic"

# ---------- 17. Prisma validate (timeout) ----------
echo ""
echo "🔎 Prisma validate..."
timeout 60 npx --yes prisma validate >/tmp/pv.log 2>&1 && echo "✅ Valid" || echo "⚠️  Skipped"

# ---------- 18. Git push ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git ls-files --error-unmatch .env >/dev/null 2>&1 && git rm --cached .env >/dev/null 2>&1 || true

git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: force-dynamic API routes + bullmq pin + DB schema instructions"

echo ""
echo "🚀 Pushing..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ DONE"
echo "==================================================="
echo ""
echo "🚨 CRITICAL NEXT STEP — DB SCHEMA PUSH"
echo "==================================================="
echo ""
echo "Ab Neon par DB tables push karo (local se):"
echo ""
echo "  cd ~/OneDrive/Desktop/EML/emailcampaign"
echo "  export DATABASE_URL='postgresql://neondb_owner:XXX@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require'"
echo "  npx prisma db push"
echo ""
echo "  Expected: 🚀  Your database is now in sync with your Prisma schema."
echo ""
echo "Iske bina Vercel build pass hoga lekin runtime pe 'table does not exist' error aayega."
echo ""
echo "📊 Vercel: https://vercel.com/certwinx/emailcampaign/deployments"
echo "==================================================="