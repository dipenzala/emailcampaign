import { prisma } from './prisma';

const TABLE = 'worker_settings';

export async function ensureTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS worker_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  } catch {}
}

export async function getSetting(key: string, fallback = ''): Promise<string> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM ${TABLE} WHERE key = $1 LIMIT 1`, key
    );
    return rows?.[0]?.value ?? fallback;
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureTable();
      return fallback;
    }
    return fallback;
  }
}

export async function setSetting(key: string, value: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${TABLE} (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key, value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureTable();
      await prisma.$executeRawUnsafe(
        `INSERT INTO ${TABLE} (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = $2`,
        key, value
      );
    } else throw e;
  }
}

export async function isWorkerEnabled() {
  return (await getSetting('worker_enabled', 'true')) !== 'false';
}
export async function enableWorker() {
  await setSetting('worker_enabled', 'true');
}
export async function disableWorker() {
  await setSetting('worker_enabled', 'false');
}
export async function isBulkWorkerEnabled() {
  return (await getSetting('bulk_worker_enabled', 'true')) !== 'false';
}
export async function enableBulkWorker() {
  await setSetting('bulk_worker_enabled', 'true');
}
export async function disableBulkWorker() {
  await setSetting('bulk_worker_enabled', 'false');
}
