import { NextResponse } from 'next/server';
import { connectRedis, redis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const t0 = Date.now();
  try {
    const pong = await connectRedis(8000);
    return NextResponse.json({
      ok: true,
      redis: pong,
      status: redis.status,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    return NextResponse.json(
      {
        ok: false,
        error: err?.message ?? String(err),
        status: redis.status,
        url_present: !!process.env.REDIS_URL,
        url_preview: (process.env.REDIS_URL || '').slice(0, 50),
        elapsed: Date.now() - t0,
      },
      { status: 500 }
    );
  }
}
