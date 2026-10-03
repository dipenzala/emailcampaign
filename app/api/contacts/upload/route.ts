import { NextResponse } from 'next/server';
import * as XLSX from 'xlsx';
import { prisma } from '@/lib/prisma';
import {
  isValidEmailSyntax,
  isDisposableEmail,
  validateDomains,
} from '@/lib/email-validator';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const form = await req.formData();
    const file = form.get('file') as File | null;
    const skipMx = form.get('skipMx') === 'true';

    if (!file) return NextResponse.json({ error: 'No file uploaded' }, { status: 400 });

    // Parse file
    const buf = Buffer.from(await file.arrayBuffer());
    const wb = XLSX.read(buf, { type: 'buffer' });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    const rows: any[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    const totalRows = rows.length;
    const emailKey = (r: any) => Object.keys(r).find((k) => /e-?mail/i.test(k));

    // Get suppression list
    const suppression = new Set(
      (await prisma.suppressionList.findMany()).map((s) => s.email.toLowerCase())
    );

    // Stats
    let invalid = 0;
    let notGmail = 0; // reused for "other domains filtered"
    let disposable = 0;
    let noMx = 0;
    let duplicates = 0;
    let suppressed = 0;

    const seen = new Set<string>();
    const candidates: { email: string; row: any; domain: string }[] = [];

    // ---------- Pass 1: syntax + duplicate + suppression + disposable ----------
    for (const r of rows) {
      const ek = emailKey(r);
      const email = ek ? String(r[ek]).trim().toLowerCase() : '';

      if (!email || !isValidEmailSyntax(email)) {
        invalid++;
        continue;
      }
      if (seen.has(email)) {
        duplicates++;
        continue;
      }
      seen.add(email);

      if (suppression.has(email)) {
        suppressed++;
        continue;
      }
      if (isDisposableEmail(email)) {
        disposable++;
        continue;
      }

      const domain = email.split('@')[1] || '';
      candidates.push({ email, row: r, domain });
    }

    // ---------- Pass 2: MX check (only unique domains — fast!) ----------
    let mxOk = new Set<string>(); // set of domains with valid MX
    if (!skipMx && candidates.length > 0) {
      const uniqueDomains = Array.from(new Set(candidates.map((c) => c.domain)));
      const mxResults = await validateDomains(uniqueDomains, 20);
      for (const [domain, hasMx] of mxResults.entries()) {
        if (hasMx) mxOk.add(domain);
      }
    } else {
      // If skip MX, allow all domains
      for (const c of candidates) mxOk.add(c.domain);
    }

    // ---------- Build valid list ----------
    const valid: any[] = [];
    for (const c of candidates) {
      if (!mxOk.has(c.domain)) {
        noMx++;
        continue;
      }
      valid.push({
        email: c.email,
        name: c.row.Name ?? c.row.name ?? '',
        company: c.row.Company ?? c.row.company ?? '',
        phone: c.row.Phone ?? c.row.phone ?? '',
        city: c.row.City ?? c.row.city ?? '',
      });
    }

    // ---------- Save valid contacts ----------
    if (valid.length > 0) {
      await Promise.all(
        valid.map((v) =>
          prisma.contact.upsert({
            where: { email: v.email },
            create: v,
            update: {
              name: v.name,
              company: v.company,
              phone: v.phone,
              city: v.city,
            },
          })
        )
      );
    }

    return NextResponse.json({
      totalRows,
      valid: valid.length,
      invalid,
      duplicates,
      suppressed,
      disposable,
      noMx,
      contacts: valid,
      mxChecked: !skipMx,
    });
  } catch (err: any) {
    console.error('[upload] error:', err);
    return NextResponse.json(
      { error: 'Upload failed', message: err?.message ?? 'Unknown error' },
      { status: 500 }
    );
  }
}
