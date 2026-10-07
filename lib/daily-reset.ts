import { prisma } from './prisma';

/**
 * DAILY RESET LOGIC
 * -----------------
 * Checks if the current day is different from each sender's lastResetAt.
 * If yes → resets sentToday, batchCount, lastResetAt = now.
 *
 * Called automatically in every worker run.
 * Runs in ~50ms (single UPDATE query).
 *
 * Reset timing:
 *   → Uses server's local time
 *   → "Today 00:00:00" is the boundary
 *   → Any sender with lastResetAt < today 00:00 = needs reset
 */

export async function autoResetIfNewDay(): Promise<{
  reset: number;
  sendersUpdated: string[];
}> {
  // Get start of today (midnight 00:00:00 server time)
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  // Find senders that need reset
  const staleSenders = await prisma.senderAccount.findMany({
    where: {
      lastResetAt: { lt: startOfToday },
    },
    select: { id: true, email: true, sentToday: true },
  });

  if (staleSenders.length === 0) {
    return { reset: 0, sendersUpdated: [] };
  }

  // Reset all at once
  await prisma.senderAccount.updateMany({
    where: {
      id: { in: staleSenders.map(s => s.id) },
    },
    data: {
      sentToday: 0,
      batchCount: 0,
      lastResetAt: new Date(),
    },
  });

  console.log(`[daily-reset] Reset ${staleSenders.length} sender(s):`,
    staleSenders.map(s => `${s.email} (was ${s.sentToday})`).join(', '));

  return {
    reset: staleSenders.length,
    sendersUpdated: staleSenders.map(s => s.email),
  };
}

/**
 * Get today's date string (for logging).
 */
export function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Get time until next midnight (ms).
 */
export function msUntilMidnight(): number {
  const now = new Date();
  const midnight = new Date();
  midnight.setHours(24, 0, 0, 0);
  return midnight.getTime() - now.getTime();
}
