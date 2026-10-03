#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔨 FORCE FIX: Rewrite routes with dash separator"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. REWRITE retry-queue route
# ==========================================
echo "📝 Rewriting retry-queue route..."

mkdir -p 'app/api/campaigns/[id]/retry-queue'

cat > 'app/api/campaigns/[id]/retry-queue/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { connectRedis } from '@/lib/redis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      select: { id: true },
    });

    if (recips.length === 0) {
      return NextResponse.json({
        ok: true,
        queued: 0,
        message: 'No QUEUED recipients found',
      });
    }

    // Connect Redis first
    try {
      await connectRedis(8000);
    } catch (e: any) {
      return NextResponse.json({
        ok: false,
        error: 'Redis not reachable',
        message: e.message,
      }, { status: 500 });
    }

    const q = getSendQueue();

    // NO COLON — use dash separator
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: {
        jobId: params.id + '-' + r.id,
        attempts: 4,
        backoff: { type: 'exponential' as const, delay: 5000 },
        removeOnComplete: 1000,
        removeOnFail: 5000,
      },
    }));

    await q.addBulk(jobs);

    return NextResponse.json({
      ok: true,
      queued: jobs.length,
      total: recips.length,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[retry-queue]', err);
    return NextResponse.json({
      error: 'Retry failed',
      message: err?.message ?? String(err),
    }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/retry-queue/route.ts'
echo "   ✅ retry-queue route rewritten"

# ==========================================
# 2. REWRITE start route
# ==========================================
echo "📝 Rewriting start route..."

mkdir -p 'app/api/campaigns/[id]/start'

cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { connectRedis } from '@/lib/redis';
import { checkEmail } from '@/lib/spam-checker';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Not found' }, { status: 404 });

    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({
      subject: campaign.subject,
      html: campaign.html,
      fromEmail: sender?.email || 'noreply@example.com',
    });

    await prisma.campaign.update({
      where: { id: params.id },
      data: { spamScore: report.score, spamIssues: report.issues as any },
    });

    if (report.blocked) {
      return NextResponse.json(
        { error: 'Spam score too high', score: report.score, issues: report.issues },
        { status: 400 }
      );
    }

    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    const recips = await prisma.campaignRecipient.findMany({
      where: { campaignId: params.id, status: 'QUEUED' },
      select: { id: true },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, queued: 0, message: 'No queued recipients' });
    }

    try {
      await connectRedis(8000);
    } catch (e: any) {
      return NextResponse.json({
        ok: true,
        queued: 0,
        total: recips.length,
        warning: 'Redis not reachable — use retry-queue later',
        redis_error: e.message,
      });
    }

    const q = getSendQueue();

    // NO COLON — use dash separator
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: {
        jobId: params.id + '-' + r.id,
        attempts: 4,
        backoff: { type: 'exponential' as const, delay: 5000 },
        removeOnComplete: 1000,
        removeOnFail: 5000,
      },
    }));

    await q.addBulk(jobs);

    return NextResponse.json({
      ok: true,
      queued: jobs.length,
      total: recips.length,
      spamScore: report.score,
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start]', err);
    return NextResponse.json(
      { error: 'Failed', message: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "   ✅ start route rewritten"

# ==========================================
# 3. VERIFY no colon remains in jobId
# ==========================================
echo ""
echo "🔎 Verifying no colon in jobId..."
COLON_COUNT=$(grep -rn 'jobId.*`[^`]*:[^`]*`' app/ 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
echo "   Colon in jobId: $COLON_COUNT"

if [ "$COLON_COUNT" -gt 0 ]; then
  echo "   ⚠️  Still has colon:"
  grep -rn 'jobId.*`[^`]*:[^`]*`' app/ 2>/dev/null | grep -v node_modules
else
  echo "   ✅ Clean — no colons in jobId"
fi

# ==========================================
# 4. Verify new code has dash separator
# ==========================================
echo ""
echo "🔎 Checking new separator:"
grep -n "jobId:" 'app/api/campaigns/[id]/retry-queue/route.ts' | head -2
grep -n "jobId:" 'app/api/campaigns/[id]/start/route.ts' | head -2

# ==========================================
# 5. Git commit + push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "FIX: jobId colon → dash separator (BullMQ v5.28+)"

git push -u origin main 2>&1 | tail -8

echo ""
echo "==============================================="
echo " ✅ PUSHED"
echo "==============================================="
echo ""
echo "⏱️  2-3 min wait karo (Vercel redeploy)"
echo ""
echo "Verify yahan:"
echo "  https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo ""
echo "🎯 Deploy hone ke BAAD ye command chalao:"
echo ""
echo "  curl -X POST \"https://emailcampaign-ten.vercel.app/api/campaigns/cmus8q2g1000ey8yazfsqm6i/retry-queue\""
echo ""
echo "Expected: {\"ok\":true,\"queued\":XXXX}"
echo "==============================================="