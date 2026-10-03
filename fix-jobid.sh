#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 Fix: BullMQ jobId separator (colon → dash)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ---------- 1. Fix start route ----------
echo "📝 Fixing /api/campaigns/[id]/start/route.ts..."

if [ -f "app/api/campaigns/[id]/start/route.ts" ]; then
  # Replace `:` in jobId with `-`
  sed -i 's|jobId: `${params.id}:${r.id}`|jobId: `${params.id}-${r.id}`|g' 'app/api/campaigns/[id]/start/route.ts'
  # Backup pattern (in case formatting differs)
  sed -i 's|`${params.id}:${r.id}`|`${params.id}-${r.id}`|g' 'app/api/campaigns/[id]/start/route.ts'
  echo "   ✅ start route"
fi

# ---------- 2. Fix retry-queue route ----------
echo "📝 Fixing /api/campaigns/[id]/retry-queue/route.ts..."

if [ -f "app/api/campaigns/[id]/retry-queue/route.ts" ]; then
  sed -i 's|jobId: `${params.id}:${r.id}`|jobId: `${params.id}-${r.id}`|g' 'app/api/campaigns/[id]/retry-queue/route.ts'
  sed -i 's|`${params.id}:${r.id}`|`${params.id}-${r.id}`|g' 'app/api/campaigns/[id]/retry-queue/route.ts'
  echo "   ✅ retry-queue route"
fi

# ---------- 3. Search for any other colon jobIds ----------
echo ""
echo "🔎 Scanning for other `${...}:${...}` jobIds..."

FOUND=$(grep -rn 'jobId.*`[^`]*:[^`]*`' app/ 2>/dev/null | grep -v node_modules || true)
if [ -n "$FOUND" ]; then
  echo "   ⚠️  Found:"
  echo "$FOUND"
  # Auto-fix
  find app -name "*.ts" -exec sed -i 's|jobId: `${\([^}]*\)}:${\([^}]*\)}`|jobId: `${\1}-\2}`|g' {} \;
  echo "   ✅ Fixed all occurrences"
else
  echo "   ✅ No other issues"
fi

# ---------- 4. Verify ----------
echo ""
echo "🔎 Verification:"
grep -n "jobId" 'app/api/campaigns/[id]/start/route.ts' 2>/dev/null | head -3 || echo "   start route not found"
grep -n "jobId" 'app/api/campaigns/[id]/retry-queue/route.ts' 2>/dev/null | head -3 || echo "   retry route not found"

# ---------- 5. Git commit + push ----------
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Fix: BullMQ jobId separator (colon not allowed)"
  echo "   ✅ Committed"
fi

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ PUSHED"
echo "==============================================="
echo ""
echo "🎯 Ab 2 min wait karo — Vercel deploy hoga"
echo ""
echo "📝 Phir retry command chalao (same campaign ID):"
echo ""
echo "  CAMPAIGN_ID=\"cmus8q2g1000ey8yazfsqm6i\""
echo "  curl -X POST \"https://emailcampaign-ten.vercel.app/api/campaigns/\$CAMPAIGN_ID/retry-queue\""
echo ""
echo "Expected: {\"ok\":true,\"queued\":1837}"
echo ""
echo "⚠️  IMPORTANT: Campaign status 'RUNNING' honi chahiye."
echo "   Agar 'STOPPED' hai to pehle naya campaign banao."
echo "==============================================="