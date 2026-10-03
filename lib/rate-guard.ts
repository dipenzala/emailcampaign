import { prisma } from './prisma';
import { effectiveLimit } from './warmup';
export async function remainingToday(senderId: string): Promise<number> {
  const s = await prisma.senderAccount.findUnique({ where: { id: senderId } });
  if (!s) return 0;
  const isWorkspace = !/@gmail\.com$/i.test(s.email);
  const providerCap = isWorkspace ? 2000 : 500;
  const warmupCap = effectiveLimit({ warmupEnabled: s.warmupEnabled, warmupDay: s.warmupDay, dailyLimit: s.dailyLimit });
  return Math.max(0, Math.min(providerCap, warmupCap, s.dailyLimit) - s.sentToday);
}
export async function canSend(senderId: string): Promise<boolean> {
  return (await remainingToday(senderId)) > 0;
}
