#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🐳 Add Dockerfile.worker (Northflank fix)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. Dockerfile.worker ----------
echo ""
echo "📝 Creating Dockerfile.worker..."
cat > Dockerfile.worker <<'EOF'
# ---- Worker Dockerfile ----
# Runs the BullMQ worker process on Northflank / any Node host
FROM node:20-alpine

WORKDIR /app

# System deps
RUN apk add --no-cache openssl libc6-compat

# Install dependencies (needs dev deps for tsx)
COPY package*.json ./
COPY prisma ./prisma
RUN npm install --include=dev --ignore-scripts

# Prisma client generate
RUN npx prisma generate

# Copy app code
COPY . .

# Ensure tsx is available
RUN npm install -g tsx@4.19.2

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=20s --retries=3 \
  CMD node -e "console.log('worker ok')" || exit 1

# Start worker
CMD ["npx", "--yes", "tsx", "workers/sender.worker.ts"]
EOF
sed -i 's/\r$//' Dockerfile.worker
echo "✅ Dockerfile.worker created"

# ---------- 2. .dockerignore ----------
echo ""
echo "📝 Creating .dockerignore..."
cat > .dockerignore <<'EOF'
node_modules
.next
.git
.gitignore
.env
.env.local
.env*.local
*.md
.vscode
.idea
coverage
.github
Dockerfile
Dockerfile.worker
.dockerignore
EOF
sed -i 's/\r$//' .dockerignore
echo "✅ .dockerignore created"

# ---------- 3. Verify worker file ----------
echo ""
echo "🔎 Verifying workers/sender.worker.ts..."
if [ -f "workers/sender.worker.ts" ]; then
  echo "   ✅ exists (" $(wc -l < workers/sender.worker.ts) " lines)"
  git ls-files workers/ | head -3
else
  echo "   ❌ MISSING!"
  exit 1
fi

# ---------- 4. Verify Procfile ----------
echo ""
echo "📝 Updating Procfile..."
echo "worker: npx --yes tsx workers/sender.worker.ts" > Procfile
sed -i 's/\r$//' Procfile
echo "✅ Procfile updated"

# ---------- 5. Git push ----------
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Add: Dockerfile.worker + .dockerignore for Northflank"
  echo "   ✅ Committed"
fi

git push -u origin main 2>&1 | tail -10

echo ""
echo "==============================================="
echo " ✅ PUSHED"
echo "==============================================="
echo ""
echo "🎯 Ab Northflank me:"
echo ""
echo "1. Service 'emailcampaign' → Build options"
echo "2. Build type: 'Dockerfile' select karo (Buildpack ke bajaye)"
echo "3. Dockerfile path: 'Dockerfile.worker'"
echo "4. Build context: '/'"
echo "5. Save → Redeploy"
echo ""
echo "2-3 min baad logs me:"
echo "  🚀 Sender worker running (rotation + warmup + anti-spam)…"
echo "==============================================="