import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const Schema = z.object({
  name: z.string().min(1),
  subject: z.string().min(1),
  html: z.string().min(20),
  scheduleStartHour: z.number().int().min(0).max(23),
  scheduleStartMinute: z.number().int().min(0).max(59),
  scheduleDurationMinutes: z.number().int().min(30).max(480),
});

// CREATE scheduled campaign
export async function POST(req: Request) {
  try {
    const parsed = Schema.safeParse(await req.json());
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
    }

    const {
      name, subject, html,
      scheduleStartHour, scheduleStartMinute, scheduleDurationMinutes,
    } = parsed.data;

    const campaign = await prisma.campaign.create({
      data: {
        name,
        subject,
        html,
        status: 'DRAFT',
        campaignType: 'scheduled',
        scheduleStartHour,
        scheduleStartMinute,
        scheduleDurationMinutes,
        batchLimit: 1,
      },
    });

    return NextResponse.json({ ok: true, id: campaign.id });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// LIST scheduled campaigns
export async function GET() {
  try {
    const list = await prisma.campaign.findMany({
      where: { campaignType: 'scheduled' },
      orderBy: { createdAt: 'desc' },
    });
    return NextResponse.json(list);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
