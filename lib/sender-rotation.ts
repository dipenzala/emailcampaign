import { prisma } from './prisma';
export async function pickNextSender(opts: { batchLimit: number }) {
  const { batchLimit } = opts;
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }, { rotationOrder: 'asc' }],
  });
  for (const s of senders) if (s.batchCount < batchLimit) return s;
  await prisma.senderAccount.updateMany({ where: { status: 'CONNECTED', isActive: true }, data: { batchCount: 0 } });
  return senders[0] ?? null;
}
export async function markSenderUsed(senderId: string) {
  return prisma.senderAccount.update({
    where: { id: senderId },
    data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
  });
}
export async function resetDailyCounters() {
  const sod = new Date();
  sod.setHours(0, 0, 0, 0);
  const r = await prisma.senderAccount.updateMany({ where: { lastResetAt: { lt: sod } }, data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() } });
  return r.count;
}
