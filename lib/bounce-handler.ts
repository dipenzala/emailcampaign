import { prisma } from './prisma';
export async function handleBounce(opts: { email: string; senderAccountId: string | null; bounceType: 'HARD'|'SOFT'|'COMPLAINT' }) {
  const { email, senderAccountId, bounceType } = opts;
  if (bounceType === 'HARD' || bounceType === 'COMPLAINT') {
    await prisma.suppressionList.upsert({
      where: { email },
      create: { email, reason: bounceType === 'HARD' ? 'BOUNCED' : 'COMPLAINT' },
      update: { reason: bounceType === 'HARD' ? 'BOUNCED' : 'COMPLAINT' },
    });
  }
  if (senderAccountId) {
    if (bounceType === 'HARD') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { hardBounces: { increment: 1 }, reputationScore: { decrement: 5 } } });
    else if (bounceType === 'SOFT') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { softBounces: { increment: 1 }, reputationScore: { decrement: 1 } } });
    else if (bounceType === 'COMPLAINT') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { complaints: { increment: 1 }, reputationScore: { decrement: 20 } } });
  }
}
