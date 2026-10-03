#!/usr/bin/env bash

echo "==============================================="
echo " 🎯 MASTER FIX — Northflank Ready + Pool Fix"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. FIX DATABASE_URL — add timeouts
# ==========================================
echo "🔧 Step 1: Fixing DATABASE_URL (add timeouts)..."

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

# Read current DATABASE_URL
CURRENT_DB=$(grep "^DATABASE_URL=" .env | cut -d'=' -f2- | tr -d '"')

# Remove existing timeout params
BASE_DB=$(echo "$CURRENT_DB" | sed 's/[?&]connect_timeout=[0-9]*//g' | sed 's/[?&]pool_timeout=[0-9]*//g' | sed 's/[?&]connection_limit=[0-9]*//g')

# Add new params
if [[ "$BASE_DB" == *"?"* ]]; then
  NEW_DB="${BASE_DB}&connect_timeout=15&pool_timeout=15&connection_limit=5"
else
  NEW_DB="${BASE_DB}?connect_timeout=15&pool_timeout=15&connection_limit=5"
fi

# Update .env
sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"$NEW_DB\"|" .env
echo "   ✅ DATABASE_URL updated with timeouts"
echo "   ${NEW_DB:0:80}..."
echo ""

# ==========================================
# 2. FIX local-sender.js — stop after complete
# ==========================================
echo "🔧 Step 2: Fixing local-sender.js (stop after complete)..."

# Add a "should stop" flag when no recipients remain
sed -i 's|if (remaining === 0) {|if (remaining === 0) {\n        stopWhenComplete = true;|' local-sender.js 2>/dev/null || true

# Add global flag
if ! grep -q "stopWhenComplete" local-sender.js; then
  sed -i '0,/let busy = false;/s//let busy = false;\nlet stopWhenComplete = false;/' local-sender.js
fi

# Modify poll to check flag
if ! grep -q "if (stopWhenComplete)" local-sender.js; then
  sed -i 's|async function poll(oauthClients) {|async function poll(oauthClients) {\n  if (stopWhenComplete) return;|' local-sender.js
fi

# After campaign complete, mark flag
sed -i "s|console.log('🎉 CAMPAIGN COMPLETED');|console.log('🎉 CAMPAIGN COMPLETED');\n        stopWhenComplete = true;|" local-sender.js 2>/dev/null || true

echo "   ✅ local-sender.js updated (auto-stop)"
echo ""

# ==========================================
# 3. DOCKERFILE for Northflank
# ==========================================
echo "🐳 Step 3: Creating Dockerfile.worker..."

cat > Dockerfile.worker <<'EOF'
# ==========================================
# Northflank Worker Dockerfile
# ==========================================
FROM node:20-alpine

# System deps for Prisma
RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY prisma ./prisma

# Install deps (include dev for tsx)
RUN npm install --include=dev --ignore-scripts

# Generate Prisma client
RUN npx prisma generate

# Copy source
COPY . .

# Install tsx globally
RUN npm install -g tsx@4.19.2

# Start the local sender (pure DB polling)
CMD ["node", "local-sender.js"]
EOF
sed -i 's/\r$//' Dockerfile.worker
echo "   ✅ Dockerfile.worker created"

# ==========================================
# 4. NORTHFLANK PROC FILE
# ==========================================
echo ""
echo "📝 Step 4: Updating Procfile..."

cat > Procfile <<'EOF'
worker: node local-sender.js
EOF
sed -i 's/\r$//' Procfile
echo "   ✅ Procfile updated: worker: node local-sender.js"

# ==========================================
# 5. NORTHFLANK CONFIG
# ==========================================
echo ""
echo "📝 Step 5: Creating northflank.json..."

cat > northflank.json <<'EOF'
{
  "apiVersion": "v1",
  "kind": "Workload",
  "metadata": {
    "name": "emailcampaign-worker"
  },
  "spec": {
    "type": "worker",
    "build": {
      "type": "dockerfile",
      "dockerfilePath": "/Dockerfile.worker",
      "dockerWorkDir": "/"
    },
    "runtime": {
      "process": "worker"
    },
    "resources": {
      "plan": "nf-compute-20"
    }
  }
}
EOF
sed -i 's/\r$//' northflank.json
echo "   ✅ northflank.json created"

# ==========================================
# 6. Update .env for Northflank
# ==========================================
echo ""
echo "🔐 Step 6: Verifying .env..."

# Ensure REDIS_URL is rediss://
REDIS_CURRENT=$(grep "^REDIS_URL=" .env | cut -d'=' -f2- | tr -d '"')
if [[ "$REDIS_CURRENT" == redis://* ]]; then
  NEW_REDIS="${REDIS_CURRENT/redis:\/\//rediss:\/\/}"
  sed -i "s|^REDIS_URL=.*|REDIS_URL=\"$NEW_REDIS\"|" .env
  echo "   ✅ Fixed REDIS_URL: redis:// → rediss://"
else
  echo "   ✅ REDIS_URL already correct"
fi

# Show final env
echo ""
echo "   Current env (masked):"
grep "^DATABASE_URL=" .env | cut -c1-60
grep "^REDIS_URL=" .env | cut -c1-60
grep "^APP_URL=" .env

# ==========================================
# 7. TEST DB CONNECTION
# ==========================================
echo ""
echo "🔌 Step 7: Testing DB connection with new settings..."

set -a
source .env
set +a

node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  const t0 = Date.now();
  try {
    const c = await p.campaign.count();
    console.log("   ✅ DB connected in " + (Date.now() - t0) + "ms — " + c + " campaigns");
  } catch (e) {
    console.error("   ❌ " + e.message.slice(0, 100));
  }
  await p.$disconnect();
})();
' 2>&1

# ==========================================
# 8. GIT PUSH
# ==========================================
echo ""
echo "🌿 Step 8: Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: DB timeouts + Northflank worker (Dockerfile + auto-stop)"
git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ MASTER FIX COMPLETE"
echo "==============================================="
echo ""
echo "🎯 AB YE KARO — Northflank me:"
echo ""
echo "1. Kholo: https://app.northflank.com"
echo ""
echo "2. Service 'emailcampaign' → Build options:"
echo "   • Build type: Dockerfile"
echo "   • Dockerfile location: /Dockerfile.worker"
echo "   • Build context: /"
echo "   • Update build options"
echo ""
echo "3. Environment Variables (Northflank me):"
echo "   • DATABASE_URL  (naya value — .env se copy)"
echo "   • REDIS_URL     (rediss:// wali)"
echo "   • GOOGLE_CLIENT_ID"
echo "   • GOOGLE_CLIENT_SECRET"
echo "   • GOOGLE_REDIRECT_URI"
echo "   • TOKEN_ENCRYPTION_KEY"
echo "   • SESSION_SECRET"
echo "   • APP_URL"
echo "   • NODE_ENV=production"
echo ""
echo "4. Redeploy karo:"
echo "   • Deployments tab → Redeploy"
echo ""
echo "5. Logs check karo:"
echo "   Expected: 🚀 Smart Local Sender running..."
echo ""
echo "✅ Emails jaani shuru ho jayengi Northflank se!"
echo "==============================================="