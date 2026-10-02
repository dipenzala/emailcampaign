import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { id: string }}) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      let closed = false;
      const send = async () => {
        if (closed) return;
        try {
          const c = await prisma.campaign.findUnique({ where:{id:params.id}});
          if (!c) { controller.close(); closed = true; return; }
          const counts = await prisma.campaignRecipient.groupBy({
            by:['status'], where:{campaignId:params.id}, _count:{_all:true},
          });
          const byStatus: Record<string,number> = {};
          counts.forEach(g => byStatus[g.status] = g._count._all);
          const pending = (byStatus.QUEUED ?? 0) + (byStatus.PROCESSING ?? 0);
          const progress = c.totalCount ? ((c.totalCount - pending)/c.totalCount)*100 : 0;
          const payload = {
            status: c.status,
            total: c.totalCount,
            queued: byStatus.QUEUED ?? 0,
            processing: byStatus.PROCESSING ?? 0,
            sent: byStatus.SENT ?? 0,
            delivered: byStatus.DELIVERED ?? 0,
            failed: byStatus.FAILED ?? 0,
            bounced: byStatus.BOUNCED ?? 0,
            suppressed: byStatus.SUPPRESSED ?? 0,
            pending,
            progress: Number(progress.toFixed(2)),
            ts: Date.now(),
          };
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
        } catch(e) { /* ignore */ }
      };
      await send();
      const iv = setInterval(send, 1500);
      // @ts-ignore
      (controller as any)._cleanup = () => { clearInterval(iv); closed = true; };
    },
    cancel() {},
  });
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  });
}
