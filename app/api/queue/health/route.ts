import { NextResponse } from 'next/server';
import { redis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const t0 = Date.now();
  try {
    const ping = await Promise.race([
      redis.ping(),
      new Promise<string>((_, rej) => setTimeout(() => rej(new Error('timeout')), 5000)),
    ]);
    return NextResponse.json({ ok: true, redis: ping, status: (redis as any).status, elapsed: Date.now() - t0 });
  } catch (err: any) {
    return NextResponse.json({
      ok: false, error: err?.message ?? String(err), status: (redis as any).status,
      url_present: !!process.env.REDIS_URL,
      url_preview: (process.env.REDIS_URL || '').slice(0, 40),
      elapsed: Date.now() - t0,
    }, { status: 500 });
  }
}
