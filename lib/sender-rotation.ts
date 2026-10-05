import { prisma } from './prisma';

const DEFAULT_BATCH_LIMIT = 1;

const WARMUP_TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];

function effectiveCap(s: any): number {
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;
  let warmupCap = s.dailyLimit || 350;
  if (s.warmupEnabled) {
    const tier = WARMUP_TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit || 350);
  }
  return Math.min(providerCap, warmupCap, s.dailyLimit || 350);
}

/**
 * ⚡ FIXED — No more false "all capped" alarms
 * Picks next sender by rotationOrder with available capacity.
 * Returns null ONLY if truly no sender available.
 */
export async function pickNextSenderStrict(opts: { batchLimit?: number } = {}) {
  const batchLimit = Math.max(1, opts.batchLimit ?? DEFAULT_BATCH_LIMIT);

  const senders = await prisma.senderAccount.findMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  if (senders.length === 0) return null;

  // Find first sender with room
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;
    if (s.batchCount < batchLimit) return s;
  }

  // All batch-full — reset batch counts and pick first available
  await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  // Truly all capped — returns null
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
  const sod = new Date();
  sod.setHours(0, 0, 0, 0);
  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: sod } },
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
    },
  });

  let currentSender: string | null = null;
  for (const s of senders) {
    if (s.sentToday < effectiveCap(s) && s.batchCount < 1) {
      currentSender = s.email;
      break;
    }
  }

  return { senders, currentSender };
}
