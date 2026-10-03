#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 FIND + KILL DYNAMIC ROUTE CONFLICTS"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. LIST ALL DYNAMIC FOLDERS
# ==========================================
echo "📋 All dynamic route folders:"
echo ""
find app -type d -name '\[*\]' 2>/dev/null | sort | sed 's/^/   /'
echo ""

# ==========================================
# 2. FIND + FIX CONFLICTS
# ==========================================
echo "🔍 Detecting conflicts..."
echo ""

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
const byParent = {};

dynamics.forEach(d => {
  const parent = path.dirname(d);
  const name = path.basename(d);
  if (!byParent[parent]) byParent[parent] = [];
  byParent[parent].push({ dir: d, name });
});

let conflicts = 0;

for (const [parent, entries] of Object.entries(byParent)) {
  const uniqueNames = [...new Set(entries.map(e => e.name))];

  if (uniqueNames.length > 1) {
    conflicts++;
    console.log(`\n❌ CONFLICT at "${parent}":`);
    entries.forEach(e => console.log(`     ${e.dir}  (${e.name})`));

    // Decide keeper: prefer [id], else first
    const keeper = entries.find(e => e.name === '[id]') || entries[0];
    console.log(`   ✅ KEEP:   ${keeper.dir}`);
    console.log(`   🗑️  DELETE:`);

    entries.forEach(e => {
      if (e.dir !== keeper.dir) {
        console.log(`     ${e.dir}`);
        try {
          fs.rmSync(e.dir, { recursive: true, force: true });
        } catch (err) {
          console.log(`     ⚠️  Failed: ${err.message}`);
        }
      }
    });
  }
}

if (conflicts === 0) {
  console.log('✅ No conflicts found — build should work');
} else {
  console.log(`\n🔧 Fixed ${conflicts} conflict(s)`);
}
NODEEOF

echo ""

# ==========================================
# 3. ALSO DELETE SPECIFIC KNOWN CONFLICTS
# ==========================================
echo "🧹 Cleaning up specific known conflicts..."

for d in \
  "app/api/campaigns/[campaignId]" \
  "app/api/campaigns/[campaign_id]" \
  "app/api/campaigns/[slug]" \
  "app/api/inbox/[messageId]" \
  "app/api/inbox/[message_id]" \
  "app/api/inbox/[msgId]" \
  "app/api/track/open/[recipientId]" \
  "app/api/track/open/[rid]" \
  "app/api/unsubscribe/[email]" \
  "app/api/unsubscribe/[code]" \
  "app/api/recipients/[recipientId]" \
  "app/api/recipients/[rid]" \
  "app/campaigns/[campaignId]" \
  "app/campaigns/[campaign_id]" ; do
  if [ -d "$d" ]; then
    echo "   🗑️  Deleting: $d"
    rm -rf "$d"
  fi
done

echo "   ✅ Done"
echo ""

# ==========================================
# 4. VERIFY
# ==========================================
echo "🔎 [4/5] Verifying..."
echo ""

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

let remaining = 0;
for (const [parent, names] of Object.entries(byParent)) {
  const u = [...new Set(names)];
  if (u.length > 1) {
    console.log(`   ❌ STILL CONFLICT: "${parent}" → ${u.join(', ')}`);
    remaining++;
  }
}

if (remaining === 0) {
  console.log('   ✅ All clean — no slug conflicts');
}
console.log('');

console.log('📋 Final dynamic routes:');
for (const [parent, names] of Object.entries(byParent).sort()) {
  console.log(`   ${parent} → ${names.join(', ')}`);
}
NODEEOF

echo ""

# ==========================================
# 5. CLEAN BUILD + PUSH
# ==========================================
echo "🧹 [5/5] Clean build + push..."

rm -rf .next 2>/dev/null || true

git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: remove duplicate dynamic routes (slug conflict)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ CONFLICTS KILLED"
echo "==============================================="
echo ""
echo "🎯 Ab Vercel pe fresh build hoga"
echo ""
echo "Check:"
echo "   https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo ""
echo "✅ 'Ready' (green) → app chalega"
echo "❌ Error → neeche wala diagnostic bhejo"
echo ""
echo "📋 Diagnostic command (agar phir bhi error):"
echo "   find app -type d -name '\\[*\\]' | sort"
echo "==============================================="