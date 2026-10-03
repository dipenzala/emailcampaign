import { prisma } from './prisma';
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];
export function effectiveLimit(sender: { warmupEnabled: boolean; warmupDay: number; dailyLimit: number }): number {
  if (!sender.warmupEnabled) return sender.dailyLimit;
  const tier = TIERS.find(t => sender.warmupDay <= t.maxDay);
  if (!tier) return sender.dailyLimit;
  return Math.min(tier.limit, sender.dailyLimit);
}
export async function advanceWarmup(): Promise<number> {
  const now = new Date();
  const senders = await prisma.senderAccount.findMany({ where: { warmupEnabled: true, status: 'CONNECTED' } });
  let updated = 0;
  for (const s of senders) {
    const days = Math.floor((now.getTime() - s.warmupStartedAt.getTime()) / (1000*60*60*24)) + 1;
    if (days !== s.warmupDay) {
      await prisma.senderAccount.update({ where: { id: s.id }, data: { warmupDay: days } });
      updated++;
    }
  }
  return updated;
}
