import { NextResponse } from 'next/server';
import { renderTemplate } from '@/lib/personalization';
import { sanitizeForPreview } from '@/lib/sanitize';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { subject, html, sample } = await req.json();
  if (!html) return NextResponse.json({ error: 'html required' }, { status: 400 });

  const data = sample || {
    name: 'Rahul Sharma',
    email: 'rahul@example.com',
    company: 'Acme Corp',
    city: 'Mumbai',
    phone: '+91 98765 43210',
  };

  const rendered = renderTemplate(html, data);
  const safe = sanitizeForPreview(rendered);
  const spam = checkEmail({ subject: subject || '', html: rendered, fromEmail: 'noreply@example.com' });

  return NextResponse.json({
    html: safe,
    raw: rendered,
    spam,
    variables: data,
  });
}
