#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🚀 NORTHFLANK FINAL — Setup + ON/OFF Button"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. FIX PRISMA SCHEMA — ensure open tracking fields
# ═══════════════════════════════════════════
echo "🔧 [1/6] Ensuring Prisma schema..."

if ! grep -q "openCount" prisma/schema.prisma; then
  node <<'NODEEOF'
const fs = require('fs');
let s = fs.readFileSync('prisma/schema.prisma', 'utf8');
if (!s.includes('openCount')) {
  s = s.replace(
    /model CampaignRecipient \{([\s\S]*?)\n\}/,
    (match, body) => `model CampaignRecipient {${body}
  firstOpenedAt   DateTime?
  lastOpenedAt    DateTime?
  openCount       Int       @default(0)
}`
  );
  fs.writeFileSync('prisma/schema.prisma', s);
  console.log('   ✅ Added tracking fields');
}
NODEEOF
fi
echo "   ✅ Schema OK"

# ═══════════════════════════════════════════
# 2. WORKER CONTROL API — ON/OFF toggle
# ═══════════════════════════════════════════
echo ""
echo "🎛️ [2/6] Creating worker control API..."

mkdir -p app/api/worker/control
mkdir -p app/api/worker/status

cat > app/api/worker/control/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { cookies } from 'next/headers';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Global worker control:
 * - POST { enabled: true }  → worker ON
 * - POST { enabled: false } → worker OFF
 *
 * Stored in a settings table (created if not exists).
 */
async function getSetting(key: string): Promise<string | null> {
  try {
    const rows: any[] = await prisma.$queryRawUnsafe(
      `SELECT value FROM worker_settings WHERE key = $1 LIMIT 1`,
      key
    );
    return rows?.[0]?.value ?? null;
  } catch (e: any) {
    // Table doesn't exist — try to create
    if (/relation.*does not exist/i.test(e.message)) {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS worker_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);
      return null;
    }
    throw e;
  }
}

async function setSetting(key: string, value: string) {
  try {
    await prisma.$executeRawUnsafe(
      `INSERT INTO worker_settings (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      key,
      value
    );
  } catch (e: any) {
    if (/relation.*does not exist/i.test(e.message)) {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS worker_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);
      await prisma.$executeRawUnsafe(
        `INSERT INTO worker_settings (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = $2`,
        key,
        value
      );
    } else {
      throw e;
    }
  }
}

export async function GET() {
  try {
    const enabled = await getSetting('worker_enabled');
    return NextResponse.json({
      ok: true,
      enabled: enabled !== 'false', // default ON if not set
    });
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
    await setSetting('worker_enabled', enabled ? 'true' : 'false');

    return NextResponse.json({ ok: true, enabled: !!enabled });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/control/route.ts

# ═══════════════════════════════════════════
# 3. STATUS API — worker last seen
# ═══════════════════════════════════════════
cat > app/api/worker/status/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    let enabled = true;
    try {
      const rows: any[] = await prisma.$queryRawUnsafe(
        `SELECT value FROM worker_settings WHERE key = 'worker_enabled' LIMIT 1`
      );
      enabled = rows?.[0]?.value !== 'false';
    } catch {}

    // Get last sent time
    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT', sentAt: { not: null } },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    const lastSentAt = lastSent?.sentAt;
    const secondsSinceLastSend = lastSentAt
      ? Math.floor((Date.now() - new Date(lastSentAt).getTime()) / 1000)
      : null;

    // Worker is "live" if it sent something in last 5 minutes
    const isLive = secondsSinceLastSend !== null && secondsSinceLastSend < 300;

    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    return NextResponse.json({
      ok: true,
      enabled,
      isLive,
      lastSentAt,
      secondsSinceLastSend,
      queued,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/status/route.ts
echo "   ✅ Control + Status APIs"

# ═══════════════════════════════════════════
# 4. ENHANCE local-sender.js — check enabled flag
# ═══════════════════════════════════════════
echo ""
echo "🔧 [3/6] Adding enable-check to worker..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'local-sender.js';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  local-sender.js not found — skip');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Add worker_enabled check at start of poll
if (!c.includes('worker_enabled')) {
  // Add a helper to check enabled
  c = c.replace(
    /async function poll\(\) \{/,
    `async function isWorkerEnabled() {
  try {
    const rows = await prisma.$queryRawUnsafe(
      \`SELECT value FROM worker_settings WHERE key = 'worker_enabled' LIMIT 1\`
    );
    return rows?.[0]?.value !== 'false';
  } catch {
    return true; // default ON
  }
}

async function poll() {`
  );

  // Add enabled check inside poll
  c = c.replace(
    /(busy = true;\n  state\.lastPollAt = new Date\(\)\.toISOString\(\);)/,
    `$1

  // Check global kill switch
  const enabled = await isWorkerEnabled();
  if (!enabled) {
    busy = false;
    return;
  }`
  );

  fs.writeFileSync(f, c);
  console.log('   ✅ Added enable-check');
} else {
  console.log('   ✅ Already has enable-check');
}
NODEEOF

# ═══════════════════════════════════════════
# 5. WORKER CONTROL PANEL — add to sidebar + page
# ═══════════════════════════════════════════
echo ""
echo "🎨 [4/6] Creating control panel page..."

mkdir -p app/control

cat > app/control/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function ControlPage() {
  const [enabled, setEnabled] = useState<boolean>(true);
  const [status, setStatus] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  const load = async () => {
    try {
      const [c, s] = await Promise.all([
        fetch('/api/worker/control').then(r => r.json()),
        fetch('/api/worker/status').then(r => r.json()),
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
    setBusy(true);
    setMsg('');
    try {
      const newState = !enabled;
      const r = await fetch('/api/worker/control', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: newState }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      setEnabled(newState);
      setMsg(newState ? '✅ Worker turned ON' : '⏸️ Worker turned OFF');
      setTimeout(() => setMsg(''), 3000);
      load();
    } catch (e: any) {
      setMsg('❌ ' + e.message);
    }
    setBusy(false);
  };

  const isLive = status?.isLive;
  const secondsAgo = status?.secondsSinceLastSend;

  const formatAgo = (s: number | null) => {
    if (s === null) return 'never';
    if (s < 60) return `${s}s ago`;
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  };

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🎛️ Worker Control</h1>
        <p className="subtitle">Master switch for the sending worker</p>
      </div>

      {msg && (
        <div className="card" style={{
          padding: 14,
          background: msg.startsWith('❌') ? '#fef2f2' : '#f0fdf4',
          borderColor: msg.startsWith('❌') ? '#fca5a5' : '#86efac',
          color: msg.startsWith('❌') ? '#991b1b' : '#065f46',
          fontWeight: 600,
          fontSize: 13,
        }}>
          {msg}
        </div>
      )}

      {/* MASTER SWITCH */}
      <div className="card" style={{
        padding: 32,
        background: enabled
          ? 'linear-gradient(135deg, rgba(16,185,129,0.08), rgba(5,150,105,0.04))'
          : 'linear-gradient(135deg, rgba(239,68,68,0.06), rgba(220,38,38,0.03))',
        borderColor: enabled ? 'rgba(16,185,129,0.4)' : 'rgba(239,68,68,0.3)',
        borderWidth: 2,
        textAlign: 'center',
      }}>
        <div style={{ fontSize: 72, marginBottom: 12 }}>
          {enabled ? '🟢' : '🔴'}
        </div>
        <div style={{ fontSize: 24, fontWeight: 800, marginBottom: 8, color: enabled ? '#065f46' : '#991b1b' }}>
          Worker is {enabled ? 'ON' : 'OFF'}
        </div>
        <div style={{ fontSize: 13, color: 'var(--fg-muted)', marginBottom: 24 }}>
          {enabled
            ? 'Northflank worker emails bhej raha hai'
            : 'Northflank worker paused hai — koi email nahi jaayegi'}
        </div>

        <button
          onClick={toggle}
          disabled={busy}
          style={{
            padding: '18px 48px',
            fontSize: 18,
            fontWeight: 800,
            borderRadius: 16,
            border: 'none',
            cursor: busy ? 'not-allowed' : 'pointer',
            background: enabled
              ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
              : 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            color: '#fff',
            boxShadow: enabled
              ? '0 12px 32px -8px rgba(239,68,68,0.5)'
              : '0 12px 32px -8px rgba(16,185,129,0.5)',
            transition: 'all .3s',
            opacity: busy ? 0.6 : 1,
          }}
        >
          {busy ? '⏳ Updating...' : (enabled ? '⏸️ TURN OFF WORKER' : '▶️ TURN ON WORKER')}
        </button>
      </div>

      {/* STATUS */}
      {status && (
        <div className="card">
          <h2 style={{ fontSize: 15, marginBottom: 16 }}>📊 Live Status</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <StatusCard
              label="Worker State"
              value={enabled ? 'ON' : 'OFF'}
              color={enabled ? '#10b981' : '#ef4444'}
            />
            <StatusCard
              label="Sending Activity"
              value={isLive ? '🟢 LIVE' : '⚪ Idle'}
              color={isLive ? '#10b981' : 'var(--fg-muted)'}
            />
            <StatusCard
              label="Last Email Sent"
              value={formatAgo(secondsAgo)}
              color="var(--fg)"
            />
            <StatusCard
              label="Queued Emails"
              value={String(status.queued ?? 0)}
              color="#f59e0b"
            />
          </div>
        </div>
      )}

      {/* INFO */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>💡 Kaise Kaam Karta Hai</div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
            • <b>Worker ON:</b> Northflank emails bhejta hai normally
            <br />
            • <b>Worker OFF:</b> Worker emails nahi bhejega (kill switch)
            <br />
            • Setting <b>5-10 sec</b> me apply hoti hai
            <br />
            • Northflank continuously running rahega, bas send karna band kar dega
          </div>
        </div>
      </div>

      {/* QUICK LINKS */}
      <div className="card">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link href="/bulk" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            📧 Bulk Sender
          </Link>
          <Link href="/senders" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            🔐 Senders
          </Link>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ flex: 1, minWidth: 140 }}>
            📊 Dashboard
          </Link>
        </div>
      </div>
    </div>
  );
}

function StatusCard({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 12, padding: 14 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>
        {value}
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/control/page.tsx

# Add to sidebar
node <<'NODEEOF'
const fs = require('fs');
const f = 'components/Sidebar.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');
if (!c.includes('/control')) {
  c = c.replace(
    /\{ href: '\/bulk', label: 'Bulk Sender', icon: '📧' \},/,
    `{ href: '/bulk', label: 'Bulk Sender', icon: '📧' },
      { href: '/control', label: 'Worker Control', icon: '🎛️' },`
  );
  // If bulk link not present, add after Worker
  if (!c.includes('/control')) {
    c = c.replace(
      /\{ href: '\/worker', label: 'Worker', icon: '🤖' \},/,
      `{ href: '/worker', label: 'Worker', icon: '🤖' },
      { href: '/control', label: 'Control', icon: '🎛️' },`
    );
  }
  fs.writeFileSync(f, c);
  console.log('   ✅ Control link added');
}
NODEEOF

# ═══════════════════════════════════════════
# 6. Git push
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: worker ON/OFF control + status API + northflank guide"

git push -u origin main 2>&1 | tail -5

echo ""
echo "🌿 [6/6] Creating Northflank setup reminder..."

cat > NORTHFLANK-REMINDER.md <<'EOF'
# 🎛️ Northflank Setup Reminder

Aapne pehle Northflank pe ye setup kiya tha — same settings rakho:

## Already Configured
- Service: emailcampaign
- Repo: dipenzala/emailcampaign
- Branch: main
- Build: npm install && npx prisma generate
- Start: npm run worker OR node local-sender.js
- Env vars: 9 variables (DATABASE_URL, REDIS_URL, etc.)

## Ab Kya Add Karna Hai

### 1. Worker Control Button Use Karne Ke Liye
Ye nahi chahiye koi Northflank change — button Vercel pe hi chalta hai.
Bas DB me `worker_settings` table banegi pehli baar.

### 2. Test Flow
1. Northflank worker already running hai
2. Vercel pe `/control` kholo
3. ON/OFF button dabao
4. 5-10 sec me worker respond karega

## Dashboard Access
- https://emailcampaign-ten.vercel.app/control → ON/OFF button
- https://emailcampaign-ten.vercel.app/bulk → Manual bulk sender
- https://emailcampaign-ten.vercel.app/dashboard/live → Live dashboard
EOF

git add NORTHFLANK-REMINDER.md 2>/dev/null || true
git commit -m "Add Northflank reminder" 2>/dev/null || true
git push 2>&1 | tail -3

echo ""
echo "==============================================="
echo " ✅ DONE"
echo "==============================================="
echo ""
echo "🎯 Kya mila:"
echo ""
echo "🎛️ CONTROL PAGE (/control):"
echo "   • Bada ON/OFF button"
echo "   • Worker state live"
echo "   • Last email sent time"
echo "   • Queued count"
echo ""
echo "🔌 APIs:"
echo "   GET  /api/worker/control  → check enabled"
echo "   POST /api/worker/control  → toggle ON/OFF"
echo "   GET  /api/worker/status   → live worker status"
echo ""
echo "⚠️  Prisma fields hain to Vercel build me auto-add honge"
echo "    (Local P1001 fix: Neon resume + .env check)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📱 Test:"
echo "   https://emailcampaign-ten.vercel.app/control"
echo "==============================================="