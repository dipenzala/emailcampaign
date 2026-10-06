#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🚀 AUTO-ENABLE WORKER ON CAMPAIGN LAUNCH"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. WORKER SETTINGS HELPER LIB
# ═══════════════════════════════════════════
echo "🔧 [1/4] Creating worker settings helper..."

mkdir -p lib

cat > lib/worker-settings.ts <<'EOF'
import { prisma } from './prisma';

const TABLE = 'worker_settings';
const KEY_ENABLED = 'worker_enabled';

/**
 * Ensure worker_settings table exists.
 */
export async function ensureSettingsTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS ${TABLE} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  } catch (e) {
    // Ignore if already exists
  }
}

/**
 * Read a setting value.
 */
export async function getSetting(key: string, fallback: string = ''): Promise<string> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM ${TABLE} WHERE key = $1 LIMIT 1`,
      key
    );
    return rows?.[0]?.value ?? fallback;
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureSettingsTable();
      return fallback;
    }
    return fallback;
  }
}

/**
 * Write a setting value.
 */
export async function setSetting(key: string, value: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${TABLE} (key, value, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key,
      value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureSettingsTable();
      await prisma.$executeRawUnsafe(
        `INSERT INTO ${TABLE} (key, value, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
        key,
        value
      );
    } else {
      throw e;
    }
  }
}

/**
 * Is worker enabled?
 */
export async function isWorkerEnabled(): Promise<boolean> {
  const v = await getSetting(KEY_ENABLED, 'true');
  return v !== 'false';
}

/**
 * Turn worker ON.
 */
export async function enableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'true');
}

/**
 * Turn worker OFF.
 */
export async function disableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'false');
}
EOF
sed -i 's/\r$//' lib/worker-settings.ts
echo "   ✅ lib/worker-settings.ts"

# ═══════════════════════════════════════════
# 2. UPDATE CONTROL API — use helper
# ═══════════════════════════════════════════
echo ""
echo "🎛️ [2/4] Updating worker control API..."

mkdir -p app/api/worker/control

cat > app/api/worker/control/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';
import {
  isWorkerEnabled,
  enableWorker,
  disableWorker,
} from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const enabled = await isWorkerEnabled();
    return NextResponse.json({ ok: true, enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, enabled: true, error: err.message });
  }
}

export async function POST(req: Request) {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { enabled } = await req.json();
    if (enabled) await enableWorker();
    else await disableWorker();

    return NextResponse.json({ ok: true, enabled: !!enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/control/route.ts
echo "   ✅ Control API (clean)"

# ═══════════════════════════════════════════
# 3. AUTO-ENABLE IN CAMPAIGN START
# ═══════════════════════════════════════════
echo ""
echo "🚀 [3/4] Adding auto-enable to campaign start API..."

mkdir -p 'app/api/campaigns/[id]/start'

cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { checkEmail } from '@/lib/spam-checker';
import { enableWorker, isWorkerEnabled } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();

  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // ── Spam check
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

    // ── Check queue has recipients
    const queuedCount = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });
    if (queuedCount === 0) {
      return NextResponse.json({ error: 'No queued recipients' }, { status: 400 });
    }

    // ═══════════════════════════════════════════
    // ⚡ AUTO-ENABLE WORKER ON LAUNCH
    // ═══════════════════════════════════════════
    const wasEnabled = await isWorkerEnabled();
    if (!wasEnabled) {
      await enableWorker();
      console.log('[start] Worker was OFF — auto-enabled');
    }

    // ── Mark campaign RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    console.log('[start] Campaign', params.id, 'RUNNING |', queuedCount, 'queued | worker:', wasEnabled ? 'was ON' : 'auto-enabled');

    return NextResponse.json({
      ok: true,
      queued: queuedCount,
      total: campaign.totalCount,
      spamScore: report.score,
      workerAutoEnabled: !wasEnabled,
      message: wasEnabled
        ? 'Campaign started. Worker already running.'
        : 'Campaign started. Worker auto-enabled.',
      elapsed: Date.now() - t0,
    });
  } catch (err: any) {
    console.error('[start] FATAL:', err);
    return NextResponse.json(
      { error: 'Failed to start', message: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/start/route.ts'
echo "   ✅ Campaign start auto-enables worker"

# ═══════════════════════════════════════════
# 4. UPDATE FRONTEND — show "auto-enabled" toast
# ═══════════════════════════════════════════
echo ""
echo "🎨 [4/4] Updating campaign launch UI..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Campaign page not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Update launch() to show worker auto-enabled message
if (!c.includes('workerAutoEnabled')) {
  c = c.replace(
    /const sj = await sr\.json\(\);\s*\n\s*if \(!sr\.ok\) throw new Error\(sj\.error \|\| 'Start failed'\);/,
    `const sj = await sr.json();
      if (!sr.ok) throw new Error(sj.error || 'Start failed');

      // Show worker auto-enable message
      if (sj.workerAutoEnabled) {
        toast('🤖 Worker auto-enabled — emails starting now', 'success');
      } else {
        toast('🚀 Campaign started', 'success');
      }`
  );
}

// Remove old toast
c = c.replace(
  /toast\('🚀 Campaign started', 'success'\);\s*\n\s*router\.push\('\/dashboard\/live'\);/,
  `router.push('/dashboard/live');`
);

fs.writeFileSync(f, c);
console.log('   ✅ Campaign UI updated');
NODEEOF

# ═══════════════════════════════════════════
# Git push
# ═══════════════════════════════════════════
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: auto-enable worker on campaign launch"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ AUTO-ENABLE ON LAUNCH DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Kya hoga:"
echo ""
echo "Before:"
echo "   Worker OFF → Campaign start → Emails stuck ❌"
echo ""
echo "After:"
echo "   Worker OFF → Campaign start → Worker AUTO-ON ✅"
echo "                             → Emails turant jaana shuru"
echo ""
echo "📊 Flow:"
echo "   1. /campaigns/new → START dabao"
echo "   2. Server check karta hai: worker ON hai?"
echo "   3. Agar OFF → auto-ON"
echo "   4. Campaign RUNNING mark"
echo "   5. Toast: '🤖 Worker auto-enabled'"
echo "   6. Live dashboard pe redirect"
echo "   7. Emails 5-10 sec me jaana shuru"
echo ""
echo "💡 Manual OFF ab bhi kaam karega:"
echo "   • Launch se pehle OFF kar sakte ho (test ke liye)"
echo "   • Launch karte hi auto-ON ho jayega"
echo "   • Ya launch ke baad manually OFF karo"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "==============================================="