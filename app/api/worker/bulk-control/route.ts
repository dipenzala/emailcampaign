import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';
import {
  isBulkWorkerEnabled,
  enableBulkWorker,
  disableBulkWorker,
} from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const enabled = await isBulkWorkerEnabled();
    return NextResponse.json({ ok: true, enabled });
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
    if (enabled) await enableBulkWorker();
    else await disableBulkWorker();

    return NextResponse.json({ ok: true, enabled: !!enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
