import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { sendQueue } from '@/lib/queue';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(_:Request,{params}:{params:{id:string}}) {
  await prisma.campaign.update({ where:{id:params.id}, data:{status:'STOPPED'} });
  const jobs = await sendQueue.getJobs(['waiting','delayed','paused']);
  for (const j of jobs) if (j.data?.campaignId === params.id) await j.remove().catch(()=>{});
  return NextResponse.json({ ok:true });
}
