#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: All Senders Capped"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# ==========================================
# 1. FIX CAMPAIGN BATCH LIMIT
# ==========================================
echo "📋 [1/4] Fixing campaign batchLimit..."

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();

  // Set batchLimit = 350 for all RUNNING campaigns
  const r = await p.campaign.updateMany({
    where: { status: 'RUNNING' },
    data: { batchLimit: 350 },
  });
  console.log(`   ✅ ${r.count} running campaign(s) → batchLimit = 350`);

  await p.$disconnect();
})().catch(e => { console.error("   ❌", e.message); process.exit(1); });
NODEEOF

# ==========================================
# 2. RESET SENDER BATCH COUNTS
# ==========================================
echo ""
echo "🔄 [2/4] Resetting sender batch counts..."

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();

  // Reset batchCount to 0 for ALL senders
  const r = await p.senderAccount.updateMany({
    data: {
      batchCount: 0,
      isActive: true,
      status: 'CONNECTED',
      dailyLimit: 350,
      warmupEnabled: false,
    },
  });
  console.log(`   ✅ ${r.count} senders reset (batchCount=0, limit=350, warmup=OFF)`);

  // Show current state
  const senders = await p.senderAccount.findMany({ take: 3 });
  console.log("");
  console.log("   Sample senders:");
  senders.forEach(s => {
    console.log(`      ${s.email}`);
    console.log(`        Sent: ${s.sentToday}/350 | Batch: ${s.batchCount} | Active: ${s.isActive}`);
  });

  await p.$disconnect();
})().catch(e => { console.error("   ❌", e.message); process.exit(1); });
NODEEOF

# ==========================================
# 3. FIX WORKER — better cap logic
# ==========================================
echo ""
echo "🔧 [3/4] Improving worker cap detection..."

mkdir -p lib

cat > lib/sender-rotation.ts <<'EOF'
import { prisma } from './prisma';

const DEFAULT_BATCH = 350;

const TIERS = [
  { maxDay: 3, limit: 350 },   // Warm-up OFF by default
  { maxDay: 7, limit: 350 },
  { maxDay: 14, limit: 350 },
  { maxDay: 30, limit: 350 },
];

function effectiveCap(s: {
  warmupEnabled: boolean;
  warmupDay: number;
  dailyLimit: number;
  email?: string;
}): number {
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;

  let cap = s.dailyLimit || 350;

  if (s.warmupEnabled) {
    const tier = TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) cap = Math.min(tier.limit, cap);
  }

  return Math.min(providerCap, cap);
}

/**
 * Pick next sender (strict sequential).
 * Falls back to "least used" if all batch-full.
 */
export async function pickNextSenderStrict(opts: { batchLimit?: number } = {}) {
  const batchLimit = Math.max(1, opts.batchLimit ?? DEFAULT_BATCH);

  const senders = await prisma.senderAccount.findMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    orderBy: [
      { rotationOrder: 'asc' },
      { createdAt: 'asc' },
    ],
  });

  if (senders.length === 0) return null;

  // 1st pass: find sender with batchCount < batchLimit AND under daily cap
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;
    if (s.batchCount < batchLimit) return s;
  }

  // All batch-full → reset batches for anyone under cap
  const reset = await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    data: { batchCount: 0 },
  });

  if (reset.count === 0) return null;

  // 2nd pass after reset
  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    const cap = effectiveCap(s);
    if (s.sentToday < cap) return s;
  }

  return null; // truly all capped
}

export async function markSenderUsed(senderId: string) {
  return prisma.senderAccount.update({
    where: { id: senderId },
    data: {
      sentToday: { increment: 1 },
      batchCount: { increment: 1 },
      lastSuccessAt: new Date(),
    },
  });
}

export async function resetDailyCounters() {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: startOfDay } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  return r.count;
}

export async function getRotationState() {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: {
      id: true, email: true, sentToday: true, dailyLimit: true,
      batchCount: true, rotationOrder: true, warmupEnabled: true,
      warmupDay: true, lastSuccessAt: true, reputationScore: true,
      isActive: true, status: true,
    },
  });

  // Current sender = first who can send
  let currentSender: string | null = null;
  for (const s of senders) {
    const cap = effectiveCap({ ...s, email: s.email });
    if (s.sentToday < cap) { currentSender = s.email; break; }
  }

  return { senders, currentSender };
}
EOF
sed -i 's/\r$//' lib/sender-rotation.ts
echo "   ✅ Worker cap logic fixed"

# ==========================================
# 4. Git push
# ==========================================
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: batchLimit=350, reset batches, smarter cap detection"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 What changed:"
echo "   ✓ Campaign batchLimit → 350"
echo "   ✓ All senders: batchCount=0, limit=350, warmup=OFF"
echo "   ✓ Worker cap logic smarter (2-pass + reset)"
echo ""
echo "🚀 Ab karo:"
echo "   1. Northflank → Deployments → Redeploy"
echo "      https://app.northflank.com/t/dipens-team/project/emailcampaign"
echo ""
echo "   2. YA local worker chalao:"
echo "      bash local-sender.sh"
echo ""
echo "3 min me 4139 emails jaana shuru ho jayenge!"
echo "==============================================="