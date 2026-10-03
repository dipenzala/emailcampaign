#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 Fix: Redis auto-connect + offline queue"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. Fix redis.ts ----------
echo ""
echo "📝 Fixing lib/redis.ts..."

cat > lib/redis.ts <<'EOF'
import IORedis from 'ioredis';

const g = globalThis as any;

function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();

  const commonOpts = {
    // Auto-connect on instantiation
    lazyConnect: false,

    // Queue commands while connecting — CRITICAL for BullMQ + Vercel
    enableOfflineQueue: true,

    // Connection reliability
    connectTimeout: 10000,
    maxRetriesPerRequest: null,   // BullMQ requirement

    // Reconnect strategy
    retryStrategy: (times: number) => {
      if (times > 10) {
        console.error('[redis] giving up after 10 retries');
        return null;
      }
      const delay = Math.min(times * 300, 3000);
      console.log('[redis] retry #' + times + ' in ' + delay + 'ms');
      return delay;
    },

    // Log connection events
    reconnectOnError: (err: Error) => {
      const target = ['READONLY', 'ETIMEDOUT'];
      return target.some(t => err.message.includes(t));
    },
  };

  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    console.warn('[redis] REDIS_URL missing or invalid — using localhost');
    return new IORedis({ host: '127.0.0.1', port: 6379, ...commonOpts });
  }

  const client = new IORedis(url, commonOpts);

  client.on('connect', () => console.log('[redis] connected'));
  client.on('ready', () => console.log('[redis] ready'));
  client.on('error', (e: Error) => console.error('[redis] error:', e.message));
  client.on('close', () => console.log('[redis] connection closed'));
  client.on('reconnecting', () => console.log('[redis] reconnecting...'));

  return client;
}

export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;

/**
 * Explicit connect + ping with timeout.
 * Use this in health checks / serverless routes.
 */
export async function connectRedis(timeoutMs = 8000): Promise<string> {
  const client = redis;
  if (client.status === 'ready') return 'PONG';

  // If not connected yet, wait for ready event
  if (client.status === 'connecting' || client.status === 'wait') {
    await new Promise<void>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('connect timeout')), timeoutMs);
      client.once('ready', () => { clearTimeout(t); resolve(); });
      client.once('error', (e: Error) => { clearTimeout(t); reject(e); });
    });
  }

  return client.ping();
}
EOF
sed -i 's/\r$//' lib/redis.ts
echo "✅ redis.ts fixed (auto-connect + offline queue)"

# ---------- 2. Fix queue.ts ----------
echo ""
echo "📝 Fixing lib/queue.ts..."

cat > lib/queue.ts <<'EOF'
import { Queue, QueueOptions } from 'bullmq';
import { redis } from './redis';

export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';

let _queue: Queue | null = null;

export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, {
    connection: redis,
    prefix: QUEUE_PREFIX,
    defaultJobOptions: {
      attempts: 4,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: 1000,
      removeOnFail: 5000,
    },
  });
  return _queue;
}

// Proxy for backward compatibility
export const sendQueue = new Proxy({} as Queue, {
  get(_t, prop) {
    const q = getSendQueue();
    const v = (q as any)[prop];
    return typeof v === 'function' ? v.bind(q) : v;
  },
});
EOF
sed -i 's/\r$//' lib/queue.ts
echo "✅ queue.ts fixed"

# ---------- 3. Fix health endpoint ----------
echo ""
echo "📝 Fixing /api/queue/health/route.ts..."

mkdir -p app/api/queue/health
cat > app/api/queue/health/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { connectRedis, redis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

export async function GET() {
  const t0 = Date.now();
  try {
    const pong = await connectRedis(8000);
    return NextResponse.json({
      ok: true,
      redis: pong,
      status: redis.status,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    return NextResponse.json(
      {
        ok: false,
        error: err?.message ?? String(err),
        status: redis.status,
        url_present: !!process.env.REDIS_URL,
        url_preview: (process.env.REDIS_URL || '').slice(0, 50),
        elapsed: Date.now() - t0,
      },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' app/api/queue/health/route.ts
echo "✅ health endpoint fixed"

# ---------- 4. Fix campaign start with proper connect ----------
echo ""
echo "📝 Fixing campaign start route..."

mkdir -p 'app/api/campaigns/[id]/start'
cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { connectRedis } from '@/lib/redis';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({
      subject: campaign.subject,
      html: campaign.html,
      fromEmail: sender?.email || 'noreply@example.com',
    });

    await prisma.campaign.update({
      where: { id: params.id },
      data: { spamScore: report.score, spamIssues: report.issues as any },
    });

    if (report.blocked) {
      return NextResponse.json(
        { error: 'Spam score too high', score: report.score, issues: report.issues },
        { status: 400 }
      );
    }

    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      select: { id: true },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, queued: 0 });
    }

    // Ensure Redis is connected BEFORE queueing
    try {
      await connectRedis(8000);
    } catch (e: any) {
      console.error('[start] Redis connect failed:', e.message);
      return NextResponse.json(
        {
          ok: true,
          queued: 0,
          total: recips.length,
          warning: 'Redis not reachable — campaign marked RUNNING. Retry via /retry-queue once Redis is back.',
          redis_error: e.message,
          elapsed: Date.now() - t0,
        },
        { status: 200 }
      );
    }

    const q = getSendQueue();
    const jobs = recips.map(r => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: { jobId: `${params.id}:${r.id}` },
    }));

    await q.addBulk(jobs);

    return NextResponse.json({
      ok: true,
      queued: jobs.length,
      total: recips.length,
      spamScore: report.score,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start]', err);
    return NextResponse.json(
      { error: 'Failed', message: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "✅ campaign start fixed"

# ---------- 5. Dedupe routes ----------
echo ""
echo "🔎 Deduping runtime/dynamic..."
node <<'NODEEOF'
const fs = require('fs'), path = require('path');
function walk(d, o=[]) {
  if (!fs.existsSync(d)) return o;
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, o);
    else if (e.name === 'route.ts') o.push(p);
  }
  return o;
}
const files = walk('app/api');
const RE = /^\s*export\s+const\s+(dynamic|runtime|maxDuration)\s*=/;
let n = 0;
for (const f of files) {
  const orig = fs.readFileSync(f, 'utf8');
  const lines = orig.split('\n').filter(l => !RE.test(l));
  let li = -1;
  for (let i = 0; i < lines.length; i++) if (/^\s*import\s/.test(lines[i])) li = i;
  const ins = ['', 'export const dynamic = "force-dynamic";', 'export const runtime = "nodejs";', ''];
  if (li >= 0) lines.splice(li + 1, 0, ...ins); else lines.unshift(...ins);
  const out = lines.join('\n').replace(/\n{3,}/g, '\n\n');
  if (out !== orig) { fs.writeFileSync(f, out); n++; }
}
console.log('   Fixed: ' + n + '/' + files.length);
NODEEOF

# ---------- 6. Git push ----------
echo ""
echo "🌿 Git..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Fix: Redis auto-connect (lazyConnect=false, enableOfflineQueue=true)"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==============================================="
echo " ✅ PUSHED"
echo "==============================================="
echo ""
echo "🎯 2-3 min baad verify karo:"
echo ""
echo "  curl https://emailcampaign-ten.vercel.app/api/queue/health"
echo ""
echo "Expected:"
echo '  {"ok":true,"redis":"PONG","status":"ready"}'
echo ""
echo "📝 Phir Northflank me:"
echo "  1. Service → Deployments → Redeploy"
echo "  2. Logs check karo"
echo ""
echo "  Expected:"
echo "    [redis] connected"
echo "    [redis] ready"
echo "    🚀 Sender worker running..."
echo "==============================================="