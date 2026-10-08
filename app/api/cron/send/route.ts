import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * Cron-friendly endpoint — call from cron-job.org, UptimeRobot, etc.
 * URL: https://your-app.vercel.app/api/cron/send?key=YOUR_SECRET
 */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const key = url.searchParams.get('key');

  // Optional security
  const secret = process.env.CRON_SECRET;
  if (secret && key !== secret) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Reuse scheduler logic
  const response = await fetch(`${process.env.APP_URL}/api/scheduler`, {
    method: 'POST',
  });
  const data = await response.json();
  return NextResponse.json({
    ...data,
    triggeredAt: new Date().toISOString(),
  });
}
