import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const checks: any = {};

  try {
    const XLSX = await import('xlsx');
    checks.xlsx = { ok: true, version: XLSX.version };
  } catch (e: any) {
    checks.xlsx = { ok: false, error: e.message };
  }

  try {
    const { prisma } = await import('@/lib/prisma');
    const count = await prisma.contact.count();
    checks.prisma = { ok: true, contacts: count };
  } catch (e: any) {
    checks.prisma = { ok: false, error: e.message };
  }

  return NextResponse.json({
    ok: true,
    timestamp: new Date().toISOString(),
    checks,
  });
}
