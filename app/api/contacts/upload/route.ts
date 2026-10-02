import { NextResponse } from 'next/server';
import * as XLSX from 'xlsx';
import { prisma } from '@/lib/prisma';
import { isValidEmail } from '@/lib/email-validator';

export const runtime = 'nodejs';

export async function POST(req: Request) {
  const form = await req.formData();
  const file = form.get('file') as File | null;
  if (!file) return NextResponse.json({ error:'No file' }, { status:400 });

  const buf = Buffer.from(await file.arrayBuffer());
  const wb = XLSX.read(buf, { type:'buffer' });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rows: any[] = XLSX.utils.sheet_to_json(sheet, { defval:'' });

  const totalRows = rows.length;
  let invalid = 0, duplicates = 0, suppressed = 0;
  const seen = new Set<string>();
  const valid: any[] = [];

  const suppression = new Set(
    (await prisma.suppressionList.findMany()).map(s => s.email.toLowerCase())
  );

  const emailKey = (r:any) => Object.keys(r).find(k => /e-?mail/i.test(k));

  for (const r of rows) {
    const ek = emailKey(r);
    const email = ek ? String(r[ek]).trim().toLowerCase() : '';
    if (!email || !isValidEmail(email)) { invalid++; continue; }
    if (seen.has(email)) { duplicates++; continue; }
    seen.add(email);
    if (suppression.has(email)) { suppressed++; continue; }
    valid.push({
      email,
      name: r.Name ?? r.name ?? '',
      company: r.Company ?? r.company ?? '',
      phone: r.Phone ?? r.phone ?? '',
      city: r.City ?? r.city ?? '',
    });
  }

  // upsert contacts
  await Promise.all(valid.map(v => prisma.contact.upsert({
    where: { email: v.email },
    create: v,
    update: { name: v.name, company: v.company, phone: v.phone, city: v.city },
  })));

  return NextResponse.json({
    totalRows, valid: valid.length, invalid, duplicates, suppressed,
    contacts: valid,
  });
}
