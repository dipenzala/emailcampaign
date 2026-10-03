import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const campaigns = await prisma.campaign.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true, name: true, subject: true, status: true,
        totalCount: true, sentCount: true, failedCount: true,
        bouncedCount: true, suppressedCount: true,
        spamScore: true, createdAt: true, completedAt: true,
      },
    });

    const headers = [
      'Campaign ID', 'Name', 'Subject', 'Status',
      'Total', 'Sent', 'Failed', 'Bounced', 'Suppressed',
      'Spam Score', 'Created At', 'Completed At',
    ];

    const escape = (v: any) => {
      if (v === null || v === undefined) return '';
      const s = String(v);
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    const rows = campaigns.map(c => [
      escape(c.id),
      escape(c.name),
      escape(c.subject),
      escape(c.status),
      escape(c.totalCount),
      escape(c.sentCount),
      escape(c.failedCount),
      escape(c.bouncedCount),
      escape(c.suppressedCount),
      escape(c.spamScore),
      escape(c.createdAt ? new Date(c.createdAt).toISOString() : ''),
      escape(c.completedAt ? new Date(c.completedAt).toISOString() : ''),
    ]);

    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const bom = '\uFEFF';
    const filename = `all_campaigns_${new Date().toISOString().slice(0, 10)}.csv`;

    return new NextResponse(bom + csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
