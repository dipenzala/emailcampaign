import { prisma } from './prisma';

/**
 * STRICT 1-BY-1 ROTATION
 * -----------------------
 * Sender 1 → 1 email → Sender 2 → 1 email → Sender 3 → 1 email
 *   → wapas Sender 1 (if batchCycle = 1)
 *
 * Uses rotationOrder for sequence.
 * Uses batchCount to know how many emails current sender has sent.
 * Uses batchLimit to know when to move to next sender.
 *
 * Default batchLimit = 1 (strict one-by-one).
 */

const DEFAULT_BATCH_LIMIT = 1;

const WARMUP_TIERS = [
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
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;

  let warmupCap = s.dailyLimit;
  if (s.warmupEnabled) {
    const tier = WARMUP_TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit);
  }

  return Math.min(providerCap, warmupCap, s.dailyLimit);
}

/**
 * Pick next sender using STRICT SEQUENTIAL order.
 * Always picks the FIRST sender (by rotationOrder) who:
 *   - is CONNECTED + active + has refreshToken
 *   - has not hit daily cap
 *   - has batchCount < batchLimit (i.e., hasn't sent enough for current cycle)
 *
 * When ALL senders hit batchLimit → reset all batches to 0 → cycle restarts.
 */
export async function pickNextSenderStrict(opts: { batchLimit?: number } = {}) {
  const batchLimit = Math.max(1, opts.batchLimit ?? DEFAULT_BATCH_LIMIT);

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

  // Find first sender with room in current batch AND under daily cap
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;       // capped — skip
    if (s.batchCount < batchLimit) return s; // has room
  }

  // All senders either batch-full OR capped.
  // If some senders are batch-full but have cap room → reset batches
  const anyWithCapRoom = senders.some(s => s.sentToday < effectiveCap(s));
  if (!anyWithCapRoom) return null; // all capped — nothing to do

  await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  // Retry after reset
  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  return null;
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

  // Determine whose turn (batchLimit default = 1)
  let currentSender: string | null = null;
  for (const s of senders) {
    const cap = effectiveCap({ ...s, email: s.email });
    if (s.sentToday >= cap) continue;
    if (s.batchCount < 1) { currentSender = s.email; break; }
  }

  return { senders, currentSender };
}
