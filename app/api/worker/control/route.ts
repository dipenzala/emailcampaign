import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Global worker control:
 * - POST { enabled: true }  → worker ON
 * - POST { enabled: false } → worker OFF
 *
 * Stored in a settings table (created if not exists).
 */
async function getSetting(key: string): Promise<string | null> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM worker_settings WHERE key = $1 LIMIT 1`,
      key
    );
    return rows?.[0]?.value ?? null;
  } catch (e: any) {
    // Table doesn't exist — try to create
    if (/relation.*does not exist/i.test(e.message)) {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS worker_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);
      return null;
    }
    throw e;
  }
}

async function setSetting(key: string, value: string) {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO worker_settings (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key,
      value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS worker_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);
      await prisma.$executeRawUnsafe(
        `INSERT INTO worker_settings (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = $2`,
        key,
        value
      );
    } else {
      throw e;
    }
  }
}

export async function GET() {
  try {
    const enabled = await getSetting('worker_enabled');
    return NextResponse.json({
      ok: true,
      enabled: enabled !== 'false', // default ON if not set
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, enabled: true, error: err.message });
  }
}

export async function POST(req: Request) {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { enabled } = await req.json();
    await setSetting('worker_enabled', enabled ? 'true' : 'false');

    return NextResponse.json({ ok: true, enabled: !!enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
