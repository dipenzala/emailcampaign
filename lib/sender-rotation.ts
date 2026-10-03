import { prisma } from './prisma';

/**
 * STRICT SEQUENTIAL ROTATION
 * --------------------------
 * Sender 1 → N emails → Sender 2 → N emails → Sender 3 → N emails
 *   → back to Sender 1 (reset batch) → ...
 *
 * Uses `rotationOrder` field for ordering.
 * Uses `batchCount` to track how many sent in current cycle.
 * Uses `lastRotationAt` (implicit via updatedAt) to determine
 * which sender goes next.
 *
 * Rules:
 *  - Only CONNECTED + isActive senders
 *  - Skip senders who hit `dailyLimit` (or warmup limit)
 *  - Move to next sender after `batchLimit` emails
 *  - After all senders hit batch, reset batchCount and start fresh
 */

const DEFAULT_BATCH = 10;

/**
 * Pick next sender using strict sequential order.
 * Returns the FIRST sender whose batchCount < batchLimit
 * AND sentToday < cap. Order by rotationOrder asc.
 */
export async function pickNextSenderStrict(opts: { batchLimit: number }) {
  const batchLimit = Math.max(1, opts.batchLimit || DEFAULT_BATCH);

  // Get all active senders ordered by rotationOrder
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

  // Find the first sender who hasn't exceeded batch AND hasn't hit daily cap
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;       // already at cap — skip
    if (s.batchCount < batchLimit) return s; // has room in current batch
  }

  // All senders either capped OR batch full
  // If everyone batch-full, reset all batches and try again
  const resetResult = await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  if (resetResult.count === 0) return null;

  // Try again after reset — pick first available (not capped)
  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  return null; // all capped
}

/**
 * Warm-up limit calculation.
 */
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];

function effectiveCap(s: {
  warmupEnabled: boolean;
  warmupDay: number;
  dailyLimit: number;
  email?: string;
}): number {
  // Hard cap based on domain
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;

  // Warm-up cap
  let warmupCap = s.dailyLimit;
  if (s.warmupEnabled) {
    const tier = TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit);
  }

  return Math.min(providerCap, warmupCap, s.dailyLimit);
}

/**
 * Called after successful send.
 */
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

/**
 * Reset daily counters (run once per day).
 */
export async function resetDailyCounters() {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: startOfDay } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  return r.count;
}

/**
 * Get current rotation state (for UI display).
 */
export async function getRotationState() {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: {
      id: true, email: true, sentToday: true, dailyLimit: true,
      batchCount: true, rotationOrder: true, warmupEnabled: true,
      warmupDay: true, lastSuccessAt: true, reputationScore: true,
    },
  });

  // Determine whose turn
  let currentSender: string | null = null;
  for (const s of senders) {
    const cap = effectiveCap({ ...s, email: s.email });
    if (s.sentToday < cap && s.batchCount < 10) {
      currentSender = s.email;
      break;
    }
  }

  return { senders, currentSender };
}
