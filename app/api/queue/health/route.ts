import { NextResponse } from 'next/server';
import { redis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const t0 = Date.now();
  try {
    const ping = await Promise.race([redis.ping(), new Promise<string>((_, rej) => setTimeout(() => rej(new Error('ping timeout')), 5000))]);
    return NextResponse.json({ ok: true, redis: ping, status: (redis as any).status, elapsed: Date.now() - t0, domain: process.env.APP_URL });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message ?? String(err), status: (redis as any).status, url_present: !!process.env.REDIS_URL, elapsed: Date.now() - t0, domain: process.env.APP_URL }, { status: 500 });
  }
}
