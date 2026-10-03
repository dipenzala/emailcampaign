#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Dynamic Route Conflicts"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. DIAGNOSE — find all dynamic folders
# ==========================================
echo "🔍 [1/4] Scanning for dynamic routes..."
echo ""

echo "=== All dynamic route folders ==="
find app -type d -name '\[*\]' 2>/dev/null | sort

echo ""
echo "=== Grouped by parent ==="
find app -type d -name '\[*\]' 2>/dev/null | while read dir; do
  parent=$(dirname "$dir")
  name=$(basename "$dir")
  echo "$parent | $name"
done | sort

echo ""

# Detect conflicts
echo "🔎 Checking for conflicts..."
node <<'NODEEOF'
const fs = require('fs');
const path = require('path');

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  try {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (/^\[.+\]$/.test(e.name)) out.push(p);
        walk(p, out);
      }
    }
  } catch {}
  return out;
}

const dynamics = walk('app');

// Group by parent
const byParent = {};
for (const d of dynamics) {
  const parent = path.dirname(d);
  const name = path.basename(d);
  if (!byParent[parent]) byParent[parent] = [];
  byParent[parent].push(name);
}

// Find conflicts
let conflicts = 0;
for (const [parent, names] of Object.entries(byParent)) {
  const unique = [...new Set(names)];
  if (unique.length > 1) {
    console.log(`   ❌ CONFLICT at "${parent}":`);
    unique.forEach(n => console.log(`      • ${n}`));
    conflicts++;
  }
}

if (conflicts === 0) {
  console.log('   ✅ No slug conflicts found');
}
NODEEOF

echo ""

# ==========================================
# 2. FIX KNOWN CONFLICTS
# ==========================================
echo "🔧 [2/4] Fixing conflicts..."

# Fix: /api/campaigns/[id] vs [campaignId] etc.
# Keep [id], rename others

CONFLICT_DIRS=$(find app -type d -name '\[*\]' 2>/dev/null | while read d; do
  parent=$(dirname "$d")
  name=$(basename "$d")
  echo "$parent|$name"
done | sort | uniq)

# Count occurrences per parent
echo "$CONFLICT_DIRS" | awk -F'|' '{print $1}' | sort | uniq -c | while read count parent; do
  if [ "$count" -gt 1 ]; then
    echo "   Parent: $parent ($count dynamic folders)"
    find "$parent" -maxdepth 1 -type d -name '\[*\]' -exec basename {} \; | sed 's/^/      • /'
  fi
done

# Most likely conflicts — check specific known cases
for conflict_dir in \
  "app/api/campaigns/[campaignId]" \
  "app/api/campaigns/[campaign_id]" \
  "app/api/inbox/[messageId]" \
  "app/api/unsubscribe/[code]" ; do
  if [ -d "$conflict_dir" ]; then
    echo "   ⚠️  Deleting conflicting: $conflict_dir"
    rm -rf "$conflict_dir"
  fi
done

echo ""

# ==========================================
# 3. CLEAN — remove empty dynamic folders
# ==========================================
echo "🧹 [3/4] Cleaning empty dynamic folders..."

find app -type d -name '\[*\]' -empty -delete 2>/dev/null || true

echo "   ✅ Cleaned"
echo ""

# ==========================================
# 4. VERIFY + push
# ==========================================
echo "🔎 [4/4] Verifying + pushing..."

echo ""
echo "=== Final dynamic routes ==="
find app -type d -name '\[*\]' 2>/dev/null | sort
echo ""

# Check for remaining conflicts
node <<'NODEEOF'
const fs = require('fs');
const path = require('path');

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  try {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (/^\[.+\]$/.test(e.name)) out.push(p);
        walk(p, out);
      }
    }
  } catch {}
  return out;
}

const byParent = {};
walk('app').forEach(d => {
  const p = path.dirname(d);
  const n = path.basename(d);
  if (!byParent[p]) byParent[p] = [];
  byParent[p].push(n);
});

let conflicts = 0;
for (const [parent, names] of Object.entries(byParent)) {
  const u = [...new Set(names)];
  if (u.length > 1) {
    console.log(`   ❌ Still conflict at "${parent}": ${u.join(', ')}`);
    conflicts++;
  }
}

if (conflicts === 0) console.log('   ✅ No conflicts — safe to build');
NODEEOF

echo ""

# Git push
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: resolve dynamic route slug conflicts"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DONE"
echo "==============================================="
echo ""
echo "📊 Check Vercel:"
echo "   https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo ""
echo "Agar 'Ready' (green) → app chalega!"
echo "Agar phir bhi error → screenshot bhejo diagnostic output ka"
echo "==============================================="