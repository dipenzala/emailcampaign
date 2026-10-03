#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Add Opened Card to Dashboard"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Write fix script to temp file (no quotes issue)
# ==========================================
echo "📝 [1/4] Writing fix script..."

cat > /tmp/fix-dashboard.js <<'JSEOF'
const fs = require('fs');

// ============ FIX LIVE DASHBOARD ============
const f = 'app/dashboard/live/page.tsx';

if (fs.existsSync(f)) {
  let content = fs.readFileSync(f, 'utf8');

  // 1. Add opened to state initialization
  if (!content.includes('opened: 0')) {
    content = content.replace(
      /processing:\s*0\s*\}/,
      "processing: 0, opened: 0 }"
    );
    console.log('   ✅ Added opened to state');
  }

  // 2. Add OPENED KPI card after SUPPRESSED
  if (!content.includes("openModal('opened')")) {
    // Try multiple patterns
    const patterns = [
      /<KPI label="SUPPRESSED" value=\{stats\.suppressed\} color="text-slate-400" onClick=\{\(\) => openModal\('suppressed'\)\} \/>/,
      /<KPI label="SUPPRESSED" value=\{stats\.suppressed\} color="text-slate-400" onClick=\{\(\)\s*=>\s*openModal\('suppressed'\)\}\s*\/>/,
    ];

    let replaced = false;
    for (const p of patterns) {
      if (p.test(content)) {
        content = content.replace(
          p,
          '<KPI label="SUPPRESSED" value={stats.suppressed} color="text-slate-400" onClick={() => openModal(\'suppressed\')} />\n        <KPI label="OPENED" value={stats.opened || 0} color="text-pink-400" onClick={() => openModal(\'opened\')} />'
        );
        replaced = true;
        console.log('   ✅ Added OPENED KPI card');
        break;
      }
    }

    if (!replaced) {
      // Fallback: insert manually
      const target = 'label="SUPPRESSED"';
      const idx = content.indexOf(target);
      if (idx > -1) {
        const endOfTag = content.indexOf('/>', idx);
        if (endOfTag > -1) {
          const insertPos = endOfTag + 2;
          const newCard = '\n        <KPI label="OPENED" value={stats.opened || 0} color="text-pink-400" onClick={() => openModal(\'opened\')} />';
          content = content.slice(0, insertPos) + newCard + content.slice(insertPos);
          console.log('   ✅ Added OPENED KPI (fallback)');
        }
      }
    }
  } else {
    console.log('   ℹ️  OPENED card already present');
  }

  // 3. Change grid from 5 cols to 6 cols
  if (content.includes('md:grid-cols-5 gap-2 mb-6')) {
    content = content.replace('md:grid-cols-5 gap-2 mb-6', 'md:grid-cols-6 gap-2 mb-6');
    console.log('   ✅ Changed grid to 6 cols');
  }

  // 4. Add 'opened' to DetailsType
  if (!content.includes("'opened'")) {
    content = content.replace(
      /type DetailsType\s*=\s*'campaigns' \| 'sent' \| 'pending' \| 'queued' \| 'processing' \| 'failed' \| 'delivered' \| 'bounced' \| 'suppressed'/,
      "type DetailsType = 'campaigns' | 'sent' | 'pending' | 'queued' | 'processing' | 'failed' | 'delivered' | 'bounced' | 'suppressed' | 'opened'"
    );
    console.log('   ✅ Added opened to DetailsType');
  }

  // 5. Add MODAL_TITLES for opened
  if (!content.includes("opened: '👁️")) {
    content = content.replace(
      /suppressed: '🚫 Suppressed Recipients',/,
      "suppressed: '🚫 Suppressed Recipients',\n  opened: '👁️ Opened Emails',"
    );
    console.log('   ✅ Added opened title');
  }

  fs.writeFileSync(f, content);
  console.log('   ✅ Dashboard updated');
} else {
  console.log('   ⚠️  Dashboard file not found');
}

// ============ FIX DETAILS API ============
const apiFile = 'app/api/live/details/route.ts';

if (fs.existsSync(apiFile)) {
  let api = fs.readFileSync(apiFile, 'utf8');

  if (!api.includes('opened:')) {
    api = api.replace(
      /processing:\s*\['PROCESSING'\],/,
      "processing: ['PROCESSING'],\n      opened: ['OPENED', 'SENT', 'DELIVERED'],"
    );
    console.log('   ✅ Details API updated');
  } else {
    console.log('   ℹ️  Details API already has opened');
  }

  fs.writeFileSync(apiFile, api);
}

console.log('');
console.log('✅ All fixes applied');
JSEOF

node /tmp/fix-dashboard.js
echo ""

# ==========================================
# 2. Verify changes
# ==========================================
echo "🔎 [2/4] Verifying..."

grep -q "OPENED" app/dashboard/live/page.tsx && echo "   ✅ OPENED card present" || echo "   ❌ OPENED card missing"
grep -q "grid-cols-6" app/dashboard/live/page.tsx && echo "   ✅ 6-column grid" || echo "   ⚠️  Still 5 cols"
grep -q "'opened'" app/dashboard/live/page.tsx && echo "   ✅ Type updated" || echo "   ⚠️  Type not updated"

echo ""

# ==========================================
# 3. Ensure other files exist
# ==========================================
echo "🔎 [3/4] Verifying other files..."

[ -f "components/AppShell.tsx" ] && echo "   ✅ AppShell" || echo "   ❌ AppShell missing"
[ -f "components/Topbar.tsx" ] && echo "   ✅ Topbar" || echo "   ❌ Topbar missing"
[ -f "components/Sidebar.tsx" ] && echo "   ✅ Sidebar" || echo "   ❌ Sidebar missing"
[ -f "app/api/track/open/[id]/route.ts" ] && echo "   ✅ Tracking API" || echo "   ❌ Tracking API missing"
[ -f "app/api/live/stats/route.ts" ] && echo "   ✅ Stats API" || echo "   ❌ Stats API missing"

echo ""

# ==========================================
# 4. Git push
# ==========================================
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: add opened card to dashboard (separate script, no quote issues)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 What's added:"
echo "   ✓ OPENED card in Live Dashboard"
echo "   ✓ Click → view who opened"
echo "   ✓ 6-column KPI grid (was 5)"
echo "   ✓ Details API supports 'opened' type"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "Test:"
echo "   https://emailcampaign-ten.vercel.app/dashboard/live"
echo ""
echo "Hard refresh (Incognito) karo:"
echo "   ⋮ → New Incognito tab"
echo "==============================================="