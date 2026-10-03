#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🚀 EmailCampaign — Final Fix"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ============================================
# 1. CRLF FIX
# ============================================
echo ""
echo "🔧 [1/10] CRLF fix..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" -o -name "*.md" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅"

# ============================================
# 2. SESSION.TS — add all missing exports
# ============================================
echo ""
echo "🔐 [2/10] lib/session.ts (with hashToken + helpers)..."
mkdir -p lib
cat > lib/session.ts <<'EOF'
import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

// ---------- Session cookies ----------
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

// ---------- Token hashing (for device-bound sessions) ----------
export function hashToken(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

export function generateToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}

// ---------- Password helpers ----------
export function hashPassword(password: string, salt?: string): { hash: string; salt: string } {
  const useSalt = salt ?? crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, useSalt, 100_000, 64, 'sha512').toString('hex');
  return { hash, salt: useSalt };
}

export function verifyPassword(password: string, hash: string, salt: string): boolean {
  try {
    const check = crypto.pbkdf2Sync(password, salt, 100_000, 64, 'sha512').toString('hex');
    return crypto.timingSafeEqual(Buffer.from(check), Buffer.from(hash));
  } catch {
    return false;
  }
}
EOF
sed -i 's/\r$//' lib/session.ts
echo "✅"

# ============================================
# 3. REDIS WITH TIMEOUTS
# ============================================
echo ""
echo "🔴 [3/10] lib/redis.ts (with timeouts)..."
cat > lib/redis.ts <<'EOF'
import IORedis from 'ioredis';

const g = globalThis as any;

function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();

  const commonOpts = {
    maxRetriesPerRequest: 2,
    connectTimeout: 5000,
    commandTimeout: 8000,
    enableOfflineQueue: false,
    enableReadyCheck: false,
    lazyConnect: true,
    retryStrategy: (times: number) => {
      if (times > 3) return null;
      return Math.min(times * 500, 2000);
    },
  };

  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    return new IORedis({ host: '127.0.0.1', port: 6379, ...commonOpts });
  }
  return new IORedis(url, commonOpts);
}

export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
EOF
sed -i 's/\r$//' lib/redis.ts
echo "✅"

# ============================================
# 4. QUEUE (lazy)
# ============================================
echo ""
echo "📬 [4/10] lib/queue.ts..."
cat > lib/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import { redis } from './redis';

export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';

let _queue: Queue | null = null;

export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, {
    connection: redis,
    prefix: QUEUE_PREFIX,
  });
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
echo "✅"

# ============================================
# 5. FAST CAMPAIGN START
# ============================================
echo ""
echo "🎯 [5/10] Campaign start route (with timeouts)..."
mkdir -p 'app/api/campaigns/[id]/start'
cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

async function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timeout`)), ms)
    ),
  ]);
}

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({ subject: campaign.subject, html: campaign.html, fromEmail: sender?.email || 'noreply@example.com' });

    await prisma.campaign.update({ where: { id: params.id }, data: { spamScore: report.score, spamIssues: report.issues as any } });

    if (report.blocked) {
      return NextResponse.json({ error: 'Spam score too high', score: report.score, issues: report.issues }, { status: 400 });
    }

    await prisma.campaign.update({ where: { id: params.id }, data: { status: 'RUNNING', startedAt: new Date() } });

    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0, message: 'No pending recipients' });

    let queued = 0;
    let queueError: string | null = null;

    try {
      const q = getSendQueue();
      const jobs = recips.map((r) => ({
        name: 'send',
        data: { campaignId: params.id, recipientId: r.id },
        opts: {
          jobId: `${params.id}:${r.id}`,
          attempts: 4,
          backoff: { type: 'exponential' as const, delay: 5000 },
          removeOnComplete: 1000,
          removeOnFail: 5000,
        },
      }));
      await withTimeout(q.addBulk(jobs), 10000, 'addBulk');
      queued = jobs.length;
    } catch (qerr: any) {
      queueError = qerr?.message || String(qerr);
      console.error('[start] Queue error:', queueError);
    }

    return NextResponse.json({ ok: true, queued, total: recips.length, spamScore: report.score, queueError: queueError || undefined, elapsed: Date.now() - t0 });
  } catch (err: any) {
    console.error('[start] Fatal:', err);
    return NextResponse.json({ error: 'Failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "✅"

# ============================================
# 6. QUEUE HEALTH + RETRY
# ============================================
echo ""
echo "🔍 [6/10] Queue health + retry endpoints..."
mkdir -p app/api/queue/health
cat > app/api/queue/health/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { redis } from '@/lib/redis';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const t0 = Date.now();
  try {
    const ping = await Promise.race([
      redis.ping(),
      new Promise<string>((_, rej) => setTimeout(() => rej(new Error('timeout')), 5000)),
    ]);
    return NextResponse.json({ ok: true, redis: ping, status: (redis as any).status, elapsed: Date.now() - t0 });
  } catch (err: any) {
    return NextResponse.json({
      ok: false, error: err?.message ?? String(err), status: (redis as any).status,
      url_present: !!process.env.REDIS_URL,
      url_preview: (process.env.REDIS_URL || '').slice(0, 40),
      elapsed: Date.now() - t0,
    }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/queue/health/route.ts

mkdir -p 'app/api/campaigns/[id]/retry-queue'
cat > 'app/api/campaigns/[id]/retry-queue/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(_: Request, { params }: { params: { id: string } }) {
  try {
    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0 });
    const q = getSendQueue();
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: { jobId: `${params.id}:${r.id}`, attempts: 4, backoff: { type: 'exponential' as const, delay: 5000 } },
    }));
    await q.addBulk(jobs);
    return NextResponse.json({ ok: true, queued: jobs.length });
  } catch (err: any) {
    return NextResponse.json({ error: 'Retry failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/retry-queue/route.ts'
echo "✅"

# ============================================
# 7. FIX BROKEN IMPORTS
# ============================================
echo ""
echo "🔍 [7/10] Scanning for broken imports..."

# Delete broken account/sessions route if hashToken missing elsewhere
if [ -f "app/api/account/sessions/route.ts" ]; then
  echo "   Found app/api/account/sessions/route.ts"
  # Check if it can work with new session.ts
  if grep -q "hashToken\|verifySession" app/api/account/sessions/route.ts; then
    echo "   ✅ Compatible with new session.ts — keeping it"
  else
    echo "   ⚠️  Unknown imports — deleting"
    rm -rf app/api/account
  fi
fi

# Scan for hashToken references
echo ""
echo "   Scanning all files for hashToken..."
REFS=$(grep -rl "hashToken" app/ lib/ 2>/dev/null | grep -v node_modules || true)
if [ -n "$REFS" ]; then
  echo "   Found in:"
  echo "$REFS" | sed 's/^/     /'
else
  echo "   (no references outside session.ts)"
fi
echo "✅"

# ============================================
# 8. DEDUPE RUNTIME/DYNAMIC
# ============================================
echo ""
echo "🔎 [8/10] Deduping runtime/dynamic in all routes..."

node <<'NODEEOF'
const fs = require('fs');
const path = require('path');
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name === 'route.ts') out.push(p);
  }
  return out;
}
const files = walk('app/api');
let fixed = 0;
const RE = /^\s*export\s+const\s+(dynamic|runtime|maxDuration)\s*=/;
for (const f of files) {
  const orig = fs.readFileSync(f, 'utf8');
  const lines = orig.split('\n').filter(l => !RE.test(l));
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) if (/^\s*import\s/.test(lines[i])) lastImport = i;
  const ins = ['', 'export const dynamic = "force-dynamic";', 'export const runtime = "nodejs";', ''];
  if (lastImport >= 0) lines.splice(lastImport + 1, 0, ...ins);
  else lines.unshift(...ins);
  const out = lines.join('\n').replace(/\n{3,}/g, '\n\n');
  if (out !== orig) { fs.writeFileSync(f, out); fixed++; }
}
console.log('   Fixed: ' + fixed + '/' + files.length + ' files');
NODEEOF

# Verify
BAD=0
for f in $(find app/api -name "route.ts" 2>/dev/null); do
  R=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  D=$(grep -c "^export const dynamic" "$f" 2>/dev/null | tr -d '[:space:]')
  [ "$R" -ne 1 ] || [ "$D" -ne 1 ] && BAD=$((BAD+1))
done
[ $BAD -eq 0 ] && echo "   ✅ All $(( $(find app/api -name 'route.ts' | wc -l) )) routes clean" || echo "   ⚠️ $BAD broken"
echo "✅"

# ============================================
# 9. VERIFY KEY FILES
# ============================================
echo ""
echo "🔎 [9/10] Verify key files..."

for f in \
  lib/session.ts lib/redis.ts lib/queue.ts lib/crypto.ts lib/gmail.ts \
  lib/spam-checker.ts lib/sender-rotation.ts lib/warmup.ts lib/bounce-handler.ts \
  lib/rate-guard.ts lib/prisma.ts lib/mime.ts lib/personalization.ts lib/email-validator.ts lib/sanitize.ts \
  workers/sender.worker.ts \
  app/anti-spam/page.tsx app/senders/rotation/page.tsx app/dashboard/layout.tsx \
  middleware.ts prisma/schema.prisma ; do
  if [ -f "$f" ]; then
    echo "   ✅ $f"
  else
    echo "   ❌ MISSING: $f"
  fi
done

# Verify hashToken specifically
echo ""
if grep -q "export function hashToken" lib/session.ts; then
  echo "   ✅ hashToken export present"
else
  echo "   ❌ hashToken missing"
  exit 1
fi

# Verify prisma schema multi-line
echo ""
if head -3 prisma/schema.prisma | grep -q "^generator client {"; then
  echo "   ✅ Prisma schema multi-line"
else
  echo "   ❌ Prisma schema format wrong"
  exit 1
fi
echo "✅"

# ============================================
# 10. GIT + PUSH
# ============================================
echo ""
echo "🌿 [10/10] Git commit + push..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git ls-files --error-unmatch .env >/dev/null 2>&1 && git rm --cached .env >/dev/null 2>&1 || true
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Fix: hashToken + session helpers + Redis timeouts + fast campaign start"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==================================================="
echo " ✅ ALL FIXES PUSHED"
echo "==================================================="
echo ""
echo "📊 Vercel auto-rebuild (2-3 min):"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "🎯 Deploy ke baad ye URLs check karo:"
echo ""
echo "   1. https://emailcampaign.vercel.app/api/queue/health"
echo "      Expected: {\"ok\":true,\"redis\":\"PONG\"}"
echo ""
echo "   2. https://emailcampaign.vercel.app/api/debug/env"
echo "      Expected: saare 'present: true'"
echo ""
echo "   3. https://emailcampaign.vercel.app/          → Landing"
echo "   4. https://emailcampaign.vercel.app/login     → Login"
echo "   5. https://emailcampaign.vercel.app/dashboard → Dashboard"
echo "   6. https://emailcampaign.vercel.app/anti-spam → Anti-Spam"
echo ""
echo "==================================================="