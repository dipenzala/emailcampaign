#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔄 DAILY RESET — Sender Limits at Midnight"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. AUTO-RESET HELPER LIB
# ═══════════════════════════════════════════
echo "📝 [1/5] Creating daily reset helper..."

cat > lib/daily-reset.ts <<'EOF'
import { prisma } from './prisma';

/**
 * DAILY RESET LOGIC
 * -----------------
 * Checks if the current day is different from each sender's lastResetAt.
 * If yes → resets sentToday, batchCount, lastResetAt = now.
 *
 * Called automatically in every worker run.
 * Runs in ~50ms (single UPDATE query).
 *
 * Reset timing:
 *   → Uses server's local time
 *   → "Today 00:00:00" is the boundary
 *   → Any sender with lastResetAt < today 00:00 = needs reset
 */

export async function autoResetIfNewDay(): Promise<{
  reset: number;
  sendersUpdated: string[];
}> {
  // Get start of today (midnight 00:00:00 server time)
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  // Find senders that need reset
  const staleSenders = await prisma.senderAccount.findMany({
    where: {
      lastResetAt: { lt: startOfToday },
    },
    select: { id: true, email: true, sentToday: true },
  });

  if (staleSenders.length === 0) {
    return { reset: 0, sendersUpdated: [] };
  }

  // Reset all at once
  await prisma.senderAccount.updateMany({
    where: {
      id: { in: staleSenders.map(s => s.id) },
    },
    data: {
      sentToday: 0,
      batchCount: 0,
      lastResetAt: new Date(),
    },
  });

  console.log(`[daily-reset] Reset ${staleSenders.length} sender(s):`,
    staleSenders.map(s => `${s.email} (was ${s.sentToday})`).join(', '));

  return {
    reset: staleSenders.length,
    sendersUpdated: staleSenders.map(s => s.email),
  };
}

/**
 * Get today's date string (for logging).
 */
export function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Get time until next midnight (ms).
 */
export function msUntilMidnight(): number {
  const now = new Date();
  const midnight = new Date();
  midnight.setHours(24, 0, 0, 0);
  return midnight.getTime() - now.getTime();
}
EOF
sed -i 's/\r$//' lib/daily-reset.ts
echo "   ✅ lib/daily-reset.ts"

# ═══════════════════════════════════════════
# 2. UPDATE BULK ROUTE — add auto-reset
# ═══════════════════════════════════════════
echo ""
echo "🔧 [2/5] Adding auto-reset to bulk route..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  bulk route not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Add import
if (!c.includes('autoResetIfNewDay')) {
  c = c.replace(
    /^(import \{ NextResponse \} from 'next\/server';)/m,
    `$1\nimport { autoResetIfNewDay } from '@/lib/daily-reset';`
  );
}

// Add call before self-heal
if (!c.includes('autoResetIfNewDay()')) {
  c = c.replace(
    /(\/\/ Self-heal\s*\n\s*try \{)/,
    `// ⚡ DAILY RESET (midnight 00:00 server time)
    try {
      const resetInfo = await autoResetIfNewDay();
      if (resetInfo.reset > 0) {
        results.dailyReset = resetInfo.reset;
      }
    } catch (e: any) {
      console.log('[bulk] daily-reset error:', e.message);
    }

    $1`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ bulk route updated');
NODEEOF

# ═══════════════════════════════════════════
# 3. UPDATE PROCESS ROUTE
# ═══════════════════════════════════════════
echo ""
echo "🔧 [3/5] Adding auto-reset to process route..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/process/route.ts';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  process route not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

if (!c.includes('autoResetIfNewDay')) {
  c = c.replace(
    /^(import \{ NextResponse \} from 'next\/server';)/m,
    `$1\nimport { autoResetIfNewDay } from '@/lib/daily-reset';`
  );

  c = c.replace(
    /(\/\/ Self-heal\s*\n\s*try \{)/,
    `// ⚡ DAILY RESET
    try {
      const resetInfo = await autoResetIfNewDay();
      if (resetInfo.reset > 0) results.dailyReset = resetInfo.reset;
    } catch (e: any) {
      console.log('[process] daily-reset error:', e.message);
    }

    $1`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ process route updated');
NODEEOF

# ═══════════════════════════════════════════
# 4. UPDATE WORKER/TICK + LOCAL-SENDER
# ═══════════════════════════════════════════
echo ""
echo "🔧 [4/5] Updating tick route + local-sender..."

# Tick route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/tick/route.ts';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

if (!c.includes('autoResetIfNewDay')) {
  c = c.replace(
    /^(import \{ NextResponse \} from 'next\/server';)/m,
    `$1\nimport { autoResetIfNewDay } from '@/lib/daily-reset';`
  );

  c = c.replace(
    /(async function handle\(\) \{)/,
    `$1
  // ⚡ DAILY RESET
  try {
    const resetInfo = await autoResetIfNewDay();
    if (resetInfo.reset > 0) results.dailyReset = resetInfo.reset;
  } catch {}
`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ tick route updated');
NODEEOF

# local-sender.js
node <<'NODEEOF'
const fs = require('fs');
const f = 'local-sender.js';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

if (!c.includes('autoResetIfNewDay')) {
  // Add helper inline
  c = c.replace(
    /let busy = false;/,
    `// ⚡ DAILY RESET helper
async function autoResetIfNewDay() {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const stale = await prisma.senderAccount.findMany({
    where: { lastResetAt: { lt: startOfToday } },
    select: { id: true, email: true, sentToday: true },
  });
  if (stale.length === 0) return 0;
  await prisma.senderAccount.updateMany({
    where: { id: { in: stale.map(s => s.id) } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  console.log(\`🔄 [daily-reset] Reset \${stale.length} sender(s)\`);
  return stale.length;
}

let busy = false;`
  );

  // Call in poll
  c = c.replace(
    /(busy = true;\s*\n\s*try \{)/,
    `busy = true;
  try {
    // Daily reset check
    await autoResetIfNewDay().catch(() => {});
    `
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ local-sender.js updated');
NODEEOF

# ═══════════════════════════════════════════
# 5. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: daily auto-reset of sender limits at midnight"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DAILY RESET DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Kaise Kaam Karega:"
echo ""
echo "Har worker run pe (har 3 sec):"
echo "  1. Check: aaj ka date > sender ka lastResetAt?"
echo "  2. Agar Haan → sentToday = 0, batchCount = 0"
echo "  3. Agar Nahi → kuch nahi"
echo ""
echo "Timeline:"
echo "   7 Oct 11:59 PM  → Last send of day"
echo "   7 Oct 12:00 AM  → Auto reset within 3 sec ✅"
echo "   8 Oct 12:01 AM  → Sender ready with 350 fresh"
echo ""
echo "Logs me dikhega:"
echo "   🔄 [daily-reset] Reset 18 sender(s)"
echo "     dipenzala1999@gmail.com (was 250)"
echo "     startup38@gmail.com (was 234)"
echo "     ..."
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📊 Verify Karo:"
echo "   1. /senders page kholo"
echo "   2. 'Sent Today' column dekho"
echo "   3. Abhi ke 250/350 → kal 0/350"
echo "==============================================="