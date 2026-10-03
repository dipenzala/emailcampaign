#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🐳 Dockerize Worker + Push"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ============================================
# 1. CRLF fix
# ============================================
echo ""
echo "🔧 [1/7] CRLF fix..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.js" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅"

# ============================================
# 2. Dockerfile
# ============================================
echo ""
echo "🐳 [2/7] Dockerfile..."
cat > Dockerfile <<'DOCKERFILE'
FROM node:20-alpine

# Install system deps for Prisma
RUN apk add --no-cache openssl

WORKDIR /app

# Copy package manifests + prisma schema first (better caching)
COPY package*.json ./
COPY prisma ./prisma

# Install ALL deps (including dev — needed for tsx)
RUN npm install --include=dev

# Generate Prisma Client
RUN npx prisma generate

# Copy rest of the source
COPY . .

# Ensure tsx binary path is on PATH
ENV PATH="/app/node_modules/.bin:${PATH}"

# Start worker
CMD ["npx", "tsx", "workers/sender.worker.ts"]
DOCKERFILE

sed -i 's/\r$//' Dockerfile
echo "✅ Dockerfile created"

# ============================================
# 3. .dockerignore
# ============================================
echo ""
echo "📝 [3/7] .dockerignore..."
cat > .dockerignore <<'DOCKERIGNORE'
node_modules
.next
.git
.gitignore
.env
.env.local
.env*.local
*.log
.vercel
.DS_Store
.vscode
coverage
Dockerfile
.dockerignore
README.md
DOCKERIGNORE

sed -i 's/\r$//' .dockerignore
echo "✅ .dockerignore created"

# ============================================
# 4. Verify worker file
# ============================================
echo ""
echo "🔎 [4/7] Checking worker file..."
if [ ! -f "workers/sender.worker.ts" ]; then
  echo "❌ workers/sender.worker.ts NOT FOUND"
  exit 1
fi
echo "✅ workers/sender.worker.ts exists"

# ============================================
# 5. Verify package.json has tsx
# ============================================
echo ""
echo "🔎 [5/7] Verifying tsx in dependencies..."
node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

pkg.dependencies = pkg.dependencies || {};
pkg.devDependencies = pkg.devDependencies || {};

// Ensure tsx in dependencies
if (pkg.devDependencies.tsx) {
  pkg.dependencies.tsx = pkg.devDependencies.tsx;
  delete pkg.devDependencies.tsx;
}
if (!pkg.dependencies.tsx) pkg.dependencies.tsx = '^4.19.2';

// Ensure typescript in deps
if (pkg.devDependencies.typescript) {
  pkg.dependencies.typescript = pkg.devDependencies.typescript;
  delete pkg.devDependencies.typescript;
}

// Ensure prisma in deps
if (pkg.devDependencies.prisma) {
  pkg.dependencies.prisma = pkg.devDependencies.prisma;
  delete pkg.devDependencies.prisma;
}

// Ensure worker script uses npx
pkg.scripts = pkg.scripts || {};
pkg.scripts.worker = 'npx --yes tsx workers/sender.worker.ts';

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ tsx in dependencies');
console.log('   ✅ worker script uses npx --yes tsx');
NODEEOF
echo "✅"

# ============================================
# 6. Verify Prisma schema
# ============================================
echo ""
echo "🔎 [6/7] Prisma schema check..."
if ! head -3 prisma/schema.prisma | grep -q "^generator client {"; then
  echo "❌ Prisma schema format wrong"
  exit 1
fi
echo "✅ Prisma schema OK"

# ============================================
# 7. Git commit + push
# ============================================
echo ""
echo "🌿 [7/7] Git commit + push..."

if [ ! -d ".git" ]; then git init; git branch -M main; fi

REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"

# Untrack .env
git ls-files --error-unmatch .env >/dev/null 2>&1 && git rm --cached .env >/dev/null 2>&1 || true

git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Feat: Dockerfile for worker deployment"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==============================================="
echo " ✅ DONE"
echo "==============================================="
echo ""
echo "🎯 Ab Northflank me MANUAL step (2 min):"
echo ""
echo "1. Ye URL kholo:"
echo "   https://app.northflank.com/t/dipens-team/project/emailcampaign/services/emailcampaign/build-options"
echo ""
echo "2. 'Build type' me 'Dockerfile' select karo"
echo ""
echo "3. Build context: / (default rakho)"
echo ""
echo "4. 'Update build options' click karo"
echo ""
echo "5. Left sidebar → Deployments → Redeploy"
echo ""
echo "6. Logs dekho (2-3 min baad):"
echo "   https://app.northflank.com/t/dipens-team/project/emailcampaign/services/emailcampaign/observe/logs"
echo ""
echo "   Expected: 🚀 Sender worker running..."
echo ""
echo "==============================================="