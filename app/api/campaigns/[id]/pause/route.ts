import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export async function POST(_:Request,{params}:{params:{id:string}}) {
  await prisma.campaign.update({ where:{id:params.id}, data:{status:'PAUSED'} });
  return NextResponse.json({ ok:true });
}
