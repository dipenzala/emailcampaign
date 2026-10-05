import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const results: any = {
    timestamp: new Date().toISOString(),
    checks: {},
  };

  // Check 1: Basic
  results.checks.basic = 'ok';

  // Check 2: xlsx
  try {
    const XLSX = await import('xlsx');
    results.checks.xlsx = {
      ok: true,
      version: XLSX.version || 'unknown',
      hasRead: typeof XLSX.read === 'function',
    };
  } catch (e: any) {
    results.checks.xlsx = { ok: false, error: e.message };
  }

  // Check 3: exceljs
  try {
    const ExcelJS = await import('exceljs');
    results.checks.exceljs = {
      ok: true,
      hasWorkbook: typeof ExcelJS.Workbook === 'function',
    };
  } catch (e: any) {
    results.checks.exceljs = { ok: false, error: e.message };
  }

  // Check 4: Prisma
  try {
    const { prisma } = await import('@/lib/prisma');
    const count = await prisma.contact.count();
    results.checks.prisma = { ok: true, contacts: count };
  } catch (e: any) {
    results.checks.prisma = { ok: false, error: e.message };
  }

  return NextResponse.json({ ok: true, ...results });
}
