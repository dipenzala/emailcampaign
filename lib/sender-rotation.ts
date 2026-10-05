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
