import { prisma } from './prisma';

const TABLE = 'worker_settings';
const KEY_ENABLED = 'worker_enabled';

/**
 * Ensure worker_settings table exists.
 */
export async function ensureSettingsTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS ${TABLE} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  } catch (e) {
    // Ignore if already exists
  }
}

/**
 * Read a setting value.
 */
export async function getSetting(key: string, fallback: string = ''): Promise<string> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM ${TABLE} WHERE key = $1 LIMIT 1`,
      key
    );
    return rows?.[0]?.value ?? fallback;
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureSettingsTable();
      return fallback;
    }
    return fallback;
  }
}

/**
 * Write a setting value.
 */
export async function setSetting(key: string, value: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${TABLE} (key, value, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key,
      value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureSettingsTable();
      await prisma.$executeRawUnsafe(
        `INSERT INTO ${TABLE} (key, value, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
        key,
        value
      );
    } else {
      throw e;
    }
  }
}

/**
 * Is worker enabled?
 */
export async function isWorkerEnabled(): Promise<boolean> {
  const v = await getSetting(KEY_ENABLED, 'true');
  return v !== 'false';
}

/**
 * Turn worker ON.
 */
export async function enableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'true');
}

/**
 * Turn worker OFF.
 */
export async function disableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'false');
}
