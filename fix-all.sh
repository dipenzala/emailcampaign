#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔧 EmailCampaign — Fix Duplicates + Push"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF fix ----------
echo ""
echo "🔧 Line endings..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅"

# ---------- 2. Show problematic file BEFORE fix ----------
echo ""
echo "📄 BEFORE — app/api/contacts/upload/route.ts (first 15 lines):"
echo "-----------------------------------------------------------"
head -15 app/api/contacts/upload/route.ts 2>/dev/null || echo "(file not found)"
echo "-----------------------------------------------------------"

# ---------- 3. Clean ALL route files (line-by-line, bulletproof) ----------
echo ""
echo "🛠️  Cleaning duplicate declarations in all route.ts files..."

node <<'NODEEOF'
const fs = require('fs');
const path = require('path');

function walk(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, files);
    else if (e.name === 'route.ts') files.push(p);
  }
  return files;
}

const files = walk('app/api');
console.log('   Found ' + files.length + ' route files');

let fixed = 0;
const DECL_REGEX = /^\s*export\s+const\s+(dynamic|runtime)\s*=/;

for (const file of files) {
  const original = fs.readFileSync(file, 'utf8');
  let lines = original.split('\n');

  // Remove ALL declaration lines
  const filtered = lines.filter(l => !DECL_REGEX.test(l));

  // Find last import line index
  let lastImport = -1;
  for (let i = 0; i < filtered.length; i++) {
    if (/^\s*import\s/.test(filtered[i])) lastImport = i;
  }

  // Insert single clean pair
  const insert = [
    '',
    'export const dynamic = "force-dynamic";',
    'export const runtime = "nodejs";',
    '',
  ];
  if (lastImport >= 0) {
    filtered.splice(lastImport + 1, 0, ...insert);
  } else {
    filtered.unshift(...insert);
  }

  // Collapse 3+ blank lines to 2
  let result = filtered.join('\n').replace(/\n{3,}/g, '\n\n');

  if (result !== original) {
    fs.writeFileSync(file, result);
    console.log('   ✓ ' + file);
    fixed++;
  }
}

console.log('');
console.log('   Total files fixed: ' + fixed);
NODEEOF

echo "✅"

# ---------- 4. Verify ----------
echo ""
echo "🔎 Verification — checking each file has exactly 1 declaration each:"
echo ""

BAD=0
FOUND=0

for f in $(find app/api -name "route.ts" 2>/dev/null); do
  FOUND=$((FOUND+1))
  R_COUNT=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  D_COUNT=$(grep -c "^export const dynamic" "$f" 2>/dev/null | tr -d '[:space:]')
  R_COUNT=${R_COUNT:-0}
  D_COUNT=${D_COUNT:-0}

  if [ "$R_COUNT" -ne 1 ] || [ "$D_COUNT" -ne 1 ]; then
    echo "   ❌ $f  (runtime=$R_COUNT dynamic=$D_COUNT)"
    BAD=$((BAD+1))
  fi
done

echo ""
echo "   Total route files: $FOUND"
if [ $BAD -eq 0 ]; then
  echo "   ✅ All files clean (1 runtime + 1 dynamic each)"
else
  echo "   ⚠️  $BAD files have issues"
fi

# ---------- 5. Show fixed file AFTER ----------
echo ""
echo "📄 AFTER — app/api/contacts/upload/route.ts (first 15 lines):"
echo "-----------------------------------------------------------"
head -15 app/api/contacts/upload/route.ts 2>/dev/null || echo "(file not found)"
echo "-----------------------------------------------------------"

# ---------- 6. Abort if still broken ----------
if [ $BAD -ne 0 ]; then
  echo ""
  echo "❌ ABORT: Kuch files fix nahi hui. Manual review zaroori."
  echo "   Screenshot bhejo is output ka."
  exit 1
fi

# ---------- 7. Git ----------
echo ""
echo "🌿 Git setup..."
if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi

REPO_URL="https://github.com/dipenzala/emailcampaign.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

# Untrack .env if needed
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  git rm --cached .env >/dev/null 2>&1 || true
fi

# ---------- 8. Commit ----------
echo ""
git add -A

if git diff --cached --quiet; then
  echo "ℹ️  No changes to commit"
else
  git commit -m "Fix: remove duplicate runtime/dynamic declarations in API routes"
  echo "✅ Committed"
fi

# ---------- 9. Push ----------
echo ""
echo "🚀 Pushing to GitHub..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED — Vercel auto-rebuild shuru"
echo "==================================================="
echo ""
echo "📊 Dashboard:"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "⏱️  2-3 min wait karo. Build logs me ye dikhna chahiye:"
echo "   ✔ Generated Prisma Client"
echo "   🚀  Your database is now in sync with your Prisma schema."
echo "   ✔ Compiled successfully"
echo "   ✓ Generating static pages (18/18)"
echo "   ✅ Deployment ready"
echo ""
echo "🎯 Success ke baad:"
echo "   /          → Landing"
echo "   /login     → Login"
echo "   /dashboard → Protected dashboard"
echo ""
echo "⚠️  Agar build phir bhi fail ho — Vercel logs ka screenshot bhejo"
echo "==================================================="