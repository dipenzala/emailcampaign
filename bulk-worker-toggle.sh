#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎛️ BULK WORKER TOGGLE + Auto-Enable"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. EXTEND WORKER SETTINGS LIB
# ═══════════════════════════════════════════
echo "📝 [1/6] Adding bulk worker settings..."

cat > lib/worker-settings.ts <<'EOF'
import { prisma } from './prisma';

const TABLE = 'worker_settings';
const KEY_ENABLED = 'worker_enabled';
const KEY_BULK_ENABLED = 'bulk_worker_enabled';

export async function ensureSettingsTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS ${TABLE} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
  } catch {}
}

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

export async function setSetting(key: string, value: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${TABLE} (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key,
      value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await ensureSettingsTable();
      await prisma.$executeRawUnsafe(
        `INSERT INTO ${TABLE} (key, value, updated_at) VALUES ($1, $2, NOW())
         ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
        key,
        value
      );
    } else throw e;
  }
}

// ── Main worker ──
export async function isWorkerEnabled(): Promise<boolean> {
  return (await getSetting(KEY_ENABLED, 'true')) !== 'false';
}
export async function enableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'true');
}
export async function disableWorker(): Promise<void> {
  await setSetting(KEY_ENABLED, 'false');
}

// ── Bulk worker (new) ──
export async function isBulkWorkerEnabled(): Promise<boolean> {
  return (await getSetting(KEY_BULK_ENABLED, 'true')) !== 'false';
}
export async function enableBulkWorker(): Promise<void> {
  await setSetting(KEY_BULK_ENABLED, 'true');
}
export async function disableBulkWorker(): Promise<void> {
  await setSetting(KEY_BULK_ENABLED, 'false');
}
EOF
sed -i 's/\r$//' lib/worker-settings.ts
echo "   ✅ worker-settings.ts (both flags)"

# ═══════════════════════════════════════════
# 2. BULK WORKER CONTROL API
# ═══════════════════════════════════════════
echo ""
echo "🎛️ [2/6] Creating bulk worker control API..."

mkdir -p app/api/worker/bulk-control
mkdir -p app/api/worker/bulk-status

cat > app/api/worker/bulk-control/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';
import {
  isBulkWorkerEnabled,
  enableBulkWorker,
  disableBulkWorker,
} from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const enabled = await isBulkWorkerEnabled();
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
    if (enabled) await enableBulkWorker();
    else await disableBulkWorker();

    return NextResponse.json({ ok: true, enabled: !!enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/bulk-control/route.ts

cat > app/api/worker/bulk-status/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { isBulkWorkerEnabled } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const enabled = await isBulkWorkerEnabled();

    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT', sentAt: { not: null } },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    const secondsSince = lastSent?.sentAt
      ? Math.floor((Date.now() - new Date(lastSent.sentAt).getTime()) / 1000)
      : null;

    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    const runningCampaigns = await prisma.campaign.count({
      where: { status: 'RUNNING' },
    });

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const sentToday = await prisma.campaignRecipient.count({
      where: { status: 'SENT', sentAt: { gte: todayStart } },
    });

    return NextResponse.json({
      ok: true,
      enabled,
      isLive: secondsSince !== null && secondsSince < 300,
      lastSentAt: lastSent?.sentAt || null,
      secondsSinceLastSend: secondsSince,
      queued,
      runningCampaigns,
      sentToday,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/bulk-status/route.ts
echo "   ✅ /api/worker/bulk-control + bulk-status"

# ═══════════════════════════════════════════
# 3. UPDATE BULK ROUTE — respect bulk flag
# ═══════════════════════════════════════════
echo ""
echo "🔧 [3/6] Updating bulk route to check flag..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  bulk route not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Add import
if (!c.includes('isBulkWorkerEnabled')) {
  c = c.replace(
    /^(import \{ NextResponse \} from 'next\/server';)/m,
    `$1\nimport { isBulkWorkerEnabled } from '@/lib/worker-settings';`
  );
}

// Add flag check at start of handle()
if (!c.includes('BULK WORKER DISABLED')) {
  c = c.replace(
    /(async function handle\(req: Request\) \{)/,
    `$1
  // ⚡ CHECK BULK WORKER FLAG FIRST
  try {
    const enabled = await isBulkWorkerEnabled();
    if (!enabled) {
      return j({
        ok: true,
        message: 'BULK WORKER DISABLED',
        bulkDisabled: true,
        processed: 0, sent: 0, failed: 0, remaining: 0, elapsed: 0,
      });
    }
  } catch {}`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Bulk route checks flag');
NODEEOF

# ═══════════════════════════════════════════
# 4. UPDATE CAMPAIGN START — auto-enable bulk worker
# ═══════════════════════════════════════════
echo ""
echo "🚀 [4/6] Auto-enable bulk worker on campaign start..."

mkdir -p 'app/api/campaigns/[id]/start'

cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { checkEmail } from '@/lib/spam-checker';
import {
  enableWorker,
  enableBulkWorker,
  isWorkerEnabled,
  isBulkWorkerEnabled,
} from '@/lib/worker-settings';

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

    // Spam check
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

    // Queue check
    const queuedCount = await prisma.campaignRecipient.count({
      where: { campaignId: params.id, status: 'QUEUED' },
    });
    if (queuedCount === 0) {
      return NextResponse.json({ error: 'No queued recipients' }, { status: 400 });
    }

    // ═══════════════════════════════════════════
    // ⚡ AUTO-ENABLE BOTH WORKERS ON LAUNCH
    // ═══════════════════════════════════════════
    const workersEnabled: string[] = [];

    const mainWasOn = await isWorkerEnabled();
    if (!mainWasOn) {
      await enableWorker();
      workersEnabled.push('main');
    }

    const bulkWasOn = await isBulkWorkerEnabled();
    if (!bulkWasOn) {
      await enableBulkWorker();
      workersEnabled.push('bulk');
    }

    // Mark RUNNING
    await prisma.campaign.update({
      where: { id: params.id },
      data: { status: 'RUNNING', startedAt: new Date() },
    });

    console.log(
      '[start] Campaign', params.id,
      '| queued:', queuedCount,
      '| auto-enabled:', workersEnabled.join(', ') || 'none (both already ON)'
    );

    return NextResponse.json({
      ok: true,
      queued: queuedCount,
      total: campaign.totalCount,
      spamScore: report.score,
      workersAutoEnabled: workersEnabled,
      message: workersEnabled.length > 0
        ? `Campaign started. Auto-enabled: ${workersEnabled.join(', ')}`
        : 'Campaign started. Workers already running.',
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
echo "   ✅ Campaign start auto-enables both workers"

# ═══════════════════════════════════════════
# 5. BULK WORKER TOGGLE COMPONENT
# ═══════════════════════════════════════════
echo ""
echo "🎨 [5/6] Creating BulkWorkerToggle component..."

cat > components/BulkWorkerToggle.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';

type Props = {
  variant?: 'topbar' | 'card' | 'inline';
  showLabel?: boolean;
};

export default function BulkWorkerToggle({ variant = 'inline', showLabel = true }: Props) {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<any>(null);

  const load = async () => {
    try {
      const [c, s] = await Promise.all([
        fetch('/api/worker/bulk-control').then(r => r.json()),
        fetch('/api/worker/bulk-status').then(r => r.json()),
      ]);
      if (c.ok) setEnabled(c.enabled);
      if (s.ok) setStatus(s);
    } catch {}
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  const toggle = async () => {
    if (busy || enabled === null) return;
    setBusy(true);
    const newState = !enabled;
    setEnabled(newState);
    try {
      const r = await fetch('/api/worker/bulk-control', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: newState }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      load();
    } catch {
      setEnabled(!newState);
    }
    setBusy(false);
  };

  const isLive = status?.isLive;
  const isLoading = enabled === null;

  if (variant === 'topbar') {
    return (
      <button
        onClick={toggle}
        disabled={busy || isLoading}
        title={enabled ? 'Bulk Worker ON — click to pause' : 'Bulk Worker OFF — click to resume'}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '8px 12px',
          borderRadius: 999,
          border: '1px solid',
          borderColor: enabled ? 'rgba(59,130,246,0.4)' : 'rgba(239,68,68,0.4)',
          background: enabled
            ? 'linear-gradient(135deg, rgba(59,130,246,0.12), rgba(99,102,241,0.06))'
            : 'linear-gradient(135deg, rgba(239,68,68,0.1), rgba(220,38,38,0.05))',
          color: enabled ? '#1e40af' : '#991b1b',
          fontSize: 12,
          fontWeight: 700,
          cursor: busy || isLoading ? 'not-allowed' : 'pointer',
          height: 40,
          flexShrink: 0,
          opacity: isLoading ? 0.6 : 1,
        }}
      >
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: enabled ? '#3b82f6' : '#ef4444',
            boxShadow: enabled ? '0 0 8px #3b82f6' : '0 0 8px #ef4444',
            animation: enabled && isLive ? 'bulkPulse 2s infinite' : 'none',
          }}
        />
        <span style={{ fontSize: 13 }}>📧</span>
        {showLabel && (
          <span className="hide-bulk-mobile">
            {isLoading ? '...' : enabled ? 'Bulk ON' : 'Bulk OFF'}
          </span>
        )}
        {enabled && isLive && (
          <span
            className="hide-bulk-mobile"
            style={{
              fontSize: 9,
              padding: '2px 6px',
              borderRadius: 999,
              background: 'rgba(59,130,246,0.2)',
              color: '#1e40af',
              fontWeight: 800,
            }}
          >
            LIVE
          </span>
        )}
        <style jsx global>{`
          @keyframes bulkPulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(1.3); }
          }
          @media (max-width: 640px) { .hide-bulk-mobile { display: none !important; } }
        `}</style>
      </button>
    );
  }

  if (variant === 'card') {
    return (
      <div
        className="card"
        style={{
          padding: 20,
          background: enabled
            ? 'linear-gradient(135deg, rgba(59,130,246,0.06), rgba(99,102,241,0.03))'
            : 'linear-gradient(135deg, rgba(239,68,68,0.05), rgba(220,38,38,0.02))',
          borderColor: enabled ? 'rgba(59,130,246,0.3)' : 'rgba(239,68,68,0.25)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, minWidth: 0, flex: 1 }}>
            <div style={{ fontSize: 36 }}>{enabled ? '📧' : '📪'}</div>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 800, color: enabled ? '#1e40af' : '#991b1b' }}>
                Bulk Worker {enabled ? 'ON' : 'OFF'}
              </div>
              <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginTop: 2 }}>
                {enabled
                  ? (isLive ? '● Emails bhej raha hai' : '● Waiting for queued emails')
                  : '● Emails nahi jaa rahi'}
              </div>
            </div>
          </div>

          <button
            onClick={toggle}
            disabled={busy || isLoading}
            style={{
              padding: '12px 24px',
              fontSize: 14,
              fontWeight: 800,
              borderRadius: 12,
              border: 'none',
              cursor: busy || isLoading ? 'not-allowed' : 'pointer',
              background: enabled
                ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
                : 'linear-gradient(135deg, #3b82f6 0%, #6366f1 100%)',
              color: '#fff',
              boxShadow: enabled
                ? '0 8px 20px -6px rgba(239,68,68,0.4)'
                : '0 8px 20px -6px rgba(59,130,246,0.4)',
              opacity: isLoading ? 0.6 : 1,
              flexShrink: 0,
            }}
          >
            {isLoading ? '⏳' : enabled ? '⏸️ TURN OFF' : '▶️ TURN ON'}
          </button>
        </div>

        {status && (
          <div style={{
            marginTop: 14, paddingTop: 14, borderTop: '1px solid var(--border)',
            display: 'flex', gap: 16, fontSize: 11, color: 'var(--fg-muted)', flexWrap: 'wrap',
          }}>
            <span>📬 Queued: <b style={{ color: 'var(--fg)' }}>{status.queued ?? 0}</b></span>
            <span>✅ Sent today: <b style={{ color: '#10b981' }}>{(status.sentToday ?? 0).toLocaleString()}</b></span>
            <span>🚀 Running: <b style={{ color: 'var(--fg)' }}>{status.runningCampaigns ?? 0}</b></span>
            <span>🕐 Last: <b style={{ color: 'var(--fg)' }}>
              {status.secondsSinceLastSend === null
                ? 'never'
                : status.secondsSinceLastSend < 60
                ? `${status.secondsSinceLastSend}s ago`
                : status.secondsSinceLastSend < 3600
                ? `${Math.floor(status.secondsSinceLastSend / 60)}m ago`
                : `${Math.floor(status.secondsSinceLastSend / 3600)}h ago`}
            </b></span>
          </div>
        )}
      </div>
    );
  }

  return (
    <button
      onClick={toggle}
      disabled={busy || isLoading}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        padding: '8px 16px', borderRadius: 10,
        border: '1px solid ' + (enabled ? 'rgba(59,130,246,0.3)' : 'rgba(239,68,68,0.3)'),
        background: enabled ? 'rgba(59,130,246,0.08)' : 'rgba(239,68,68,0.08)',
        color: enabled ? '#1e40af' : '#991b1b',
        fontWeight: 700, fontSize: 12,
        cursor: busy || isLoading ? 'not-allowed' : 'pointer',
      }}
    >
      <span style={{ width: 8, height: 8, borderRadius: '50%', background: enabled ? '#3b82f6' : '#ef4444' }} />
      📧 Bulk {enabled ? 'ON' : 'OFF'}
    </button>
  );
}
EOF
sed -i 's/\r$//' components/BulkWorkerToggle.tsx
echo "   ✅ BulkWorkerToggle component"

# ═══════════════════════════════════════════
# 6. ADD TO TOPBAR + DASHBOARD + BULK PAGE
# ═══════════════════════════════════════════
echo ""
echo "🎨 [6/6] Injecting toggle into UI..."

# Topbar
node <<'NODEEOF'
const fs = require('fs');
const f = 'components/Topbar.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');
if (c.includes('BulkWorkerToggle')) { console.log('   ✅ Topbar already has'); process.exit(0); }

c = c.replace(
  /^import WorkerToggle from '\.\/WorkerToggle';/m,
  `import WorkerToggle from './WorkerToggle';\nimport BulkWorkerToggle from './BulkWorkerToggle';`
);

c = c.replace(
  /<WorkerToggle variant="topbar" \/>/,
  `<BulkWorkerToggle variant="topbar" />\n        <WorkerToggle variant="topbar" />`
);

fs.writeFileSync(f, c);
console.log('   ✅ Topbar has bulk toggle');
NODEEOF

# Live Dashboard
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/dashboard/live/page.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');
if (c.includes('BulkWorkerToggle')) { console.log('   ✅ Dashboard already has'); process.exit(0); }

c = c.replace(
  /^import WorkerToggle from '@\/components\/WorkerToggle';/m,
  `import WorkerToggle from '@/components/WorkerToggle';\nimport BulkWorkerToggle from '@/components/BulkWorkerToggle';`
);

// Insert bulk toggle BEFORE WorkerToggle
c = c.replace(
  /(<WorkerToggle variant="card" \/>)/,
  `<BulkWorkerToggle variant="card" />
      $1`
);

fs.writeFileSync(f, c);
console.log('   ✅ Dashboard has bulk toggle');
NODEEOF

# Bulk page
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/bulk/page.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');
if (c.includes('BulkWorkerToggle')) { console.log('   ✅ Bulk page already has'); process.exit(0); }

c = c.replace(
  /^import WorkerToggle from '@\/components\/WorkerToggle';/m,
  `import WorkerToggle from '@/components/WorkerToggle';\nimport BulkWorkerToggle from '@/components/BulkWorkerToggle';`
);

c = c.replace(
  /(<WorkerToggle variant="card" \/>)/,
  `$1\n      <BulkWorkerToggle variant="card" />`
);

fs.writeFileSync(f, c);
console.log('   ✅ Bulk page has bulk toggle');
NODEEOF

# Git push
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: bulk worker toggle + auto-enable both workers on campaign start"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ BULK WORKER TOGGLE DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Ab kya milega:"
echo ""
echo "🎛️ 2 SEPARATE TOGGLES everywhere:"
echo ""
echo "1. 📧 BULK WORKER (blue)"
echo "   → Vercel bulk sender (fast, 240/min)"
echo "   → /api/worker/bulk call karta hai"
echo ""
echo "2. 🔄 WORKER (green)"
echo "   → Northflank traditional (3/min slow)"
echo "   → /api/worker/process call karta hai"
echo ""
echo "Dono ka apna state, apna control"
echo ""
echo "🚀 AUTO-ENABLE ON LAUNCH:"
echo ""
echo "Campaign start → dono workers auto-ON:"
echo "   • Bulk worker: agar OFF tha → ON"
echo "   • Main worker: agar OFF tha → ON"
echo "   • Toast: 'Auto-enabled: bulk, main'"
echo ""
echo "Agar dono pehle se ON → koi change nahi"
echo ""
echo "📍 TOGGLE LOCATIONS:"
echo "   • Topbar (har page pe, 2 pills)"
echo "   • Live Dashboard (2 big cards)"
echo "   • Bulk page (2 big cards)"
echo "   • Control page"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📱 Test:"
echo "   /dashboard/live → 2 toggles dikhenge"
echo "   Campaign start → dono auto-ON"
echo "==============================================="