import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: {
        recipients: {
          include: {
            contact: true,
          },
          orderBy: { queuedAt: 'asc' },
        },
      },
    });

    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Build CSV
    const headers = [
      'Email',
      'Name',
      'Company',
      'Phone',
      'City',
      'Status',
      'Sent At',
      'Failed At',
      'Error',
    ];

    const escape = (v: any) => {
      if (v === null || v === undefined) return '';
      const s = String(v);
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    const rows = campaign.recipients.map(r => [
      escape(r.contact.email),
      escape(r.contact.name),
      escape(r.contact.company),
      escape(r.contact.phone),
      escape(r.contact.city),
      escape(r.status),
      escape(r.sentAt ? new Date(r.sentAt).toISOString() : ''),
      escape(r.failedAt ? new Date(r.failedAt).toISOString() : ''),
      escape(r.errorMessage),
    ]);

    const csv = [
      headers.join(','),
      ...rows.map(row => row.join(',')),
    ].join('\n');

    // Add BOM for Excel compatibility
    const bom = '\uFEFF';
    const filename = `${campaign.name.replace(/[^a-z0-9]/gi, '_')}_recipients.csv`;

    return new NextResponse(bom + csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Cache-Control': 'no-cache',
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
