#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 Fix: tsx not found in Northflank"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# 1. Update package.json scripts
echo ""
echo "📦 Updating package.json..."
node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

pkg.dependencies = pkg.dependencies || {};
pkg.devDependencies = pkg.devDependencies || {};

// Ensure tsx is in dependencies (not devDeps)
if (pkg.devDependencies.tsx) {
  pkg.dependencies.tsx = pkg.devDependencies.tsx;
  delete pkg.devDependencies.tsx;
}
if (!pkg.dependencies.tsx) {
  pkg.dependencies.tsx = '^4.19.2';
}

// Ensure typescript + prisma are in deps too
if (pkg.devDependencies.typescript) {
  pkg.dependencies.typescript = pkg.devDependencies.typescript;
  delete pkg.devDependencies.typescript;
}
if (pkg.devDependencies.prisma) {
  pkg.dependencies.prisma = pkg.devDependencies.prisma;
  delete pkg.devDependencies.prisma;
}

// FIX: use npx --yes tsx for worker (self-healing)
pkg.scripts = pkg.scripts || {};
pkg.scripts.worker = 'npx --yes tsx workers/sender.worker.ts';

// Also for start and dev (in case they use tsx)
pkg.scripts.start = 'npx --yes tsx workers/sender.worker.ts';

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ tsx in dependencies');
console.log('   ✅ worker script: npx --yes tsx workers/sender.worker.ts');
NODEEOF

# 2. Update Procfile
echo ""
echo "📝 Updating Procfile..."
cat > Procfile <<'EOF'
worker: npx --yes tsx workers/sender.worker.ts
EOF
sed -i 's/\r$//' Procfile
echo "   ✅ Procfile: worker: npx --yes tsx workers/sender.worker.ts"

# 3. Check worker file exists
echo ""
if [ ! -f "workers/sender.worker.ts" ]; then
  echo "❌ workers/sender.worker.ts not found!"
  exit 1
fi
echo "✅ workers/sender.worker.ts exists"

# 4. Verify Prisma schema is valid
echo ""
echo "🔎 Prisma schema check..."
head -3 prisma/schema.prisma | grep -q "^generator client {" && echo "   ✅ Schema format OK"

# 5. Git push
echo ""
echo "🌿 Git push..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Fix: use npx --yes tsx for worker (Northflank runtime fix)"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==============================================="
echo " ✅ PUSHED"
echo "==============================================="
echo ""
echo "🎯 Ab Northflank me MANUAL step:"
echo ""
echo "1. Northflank kholo: app.northflank.com"
echo "2. Service 'emailcampaign' → Settings"
echo "3. Start Command change karo:"
echo "   ❌ npm run worker"
echo "   ✅ npx --yes tsx workers/sender.worker.ts"
echo "4. Save → Redeploy"
echo ""
echo "Ya git push ke baad auto-deploy hoga"
echo ""
echo "📊 Verify 2 min baad:"
echo "   Northflank → Logs tab"
echo "   Expected: 🚀 Sender worker running..."
echo "==============================================="