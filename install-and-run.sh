#!/usr/bin/env bash

echo "==============================================="
echo " 📦 Install Dependencies + Run Worker"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ============================================
# 1. ENV VARS — APNI VALUES DAALO
# ============================================
export DATABASE_URL="postgresql://neondb_owner:npg_XXX@ep-xxx-pooler.c-6.us-east-2.aws.neon.tech/neondb?sslmode=require"
export REDIS_URL="rediss://default:gQAAAAAABLZ2AAIgcDE5OGMwOGM4NDA2ODU0NGJiYTI0OTlmM2VmMzFhNmQ4YQ@selected-lion-308854.upstash.io:6379"
export GOOGLE_CLIENT_ID="xxx.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-xxx"
export GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
export TOKEN_ENCRYPTION_KEY="f371f9f48cc14371b941f26f23afe6d37462b143b48187457a2ea0eb642ade02"
export SESSION_SECRET="8a5880c2c17e072ec23a79da604e6f3ac1e60e88302d01bdd1844d80fe6ad62aad2f1cadc66ec63df1405f9e1188ae3a"
export APP_URL="https://emailcampaign-ten.vercel.app"
export NODE_ENV="production"
export PRISMA_SKIP_POSTINSTALL_GENERATE="true"
export PRISMA_CLIENT_ENGINE_TYPE="library"

echo "✅ Env vars set"
echo ""

# ============================================
# 2. INSTALL DEPS — IGNORE SCRIPTS
# ============================================
echo "📦 Installing dependencies (skip Prisma binary downloads)..."
echo ""

# Critical: --ignore-scripts to skip Prisma binary download (TLS issue)
npm install --ignore-scripts --no-audit --no-fund --silent 2>&1 | tail -5

echo ""
echo "✅ Dependencies installed"
echo ""

# Verify key packages
echo "🔍 Verifying packages..."
for pkg in bullmq ioredis googleapis @prisma/client tsx; do
  if [ -d "node_modules/$pkg" ]; then
    echo "   ✅ $pkg"
  else
    echo "   ❌ $pkg MISSING"
  fi
done
echo ""

# ============================================
# 3. PRISMA GENERATE — NO ENGINE
# ============================================
echo "🔧 Generating Prisma Client (no engine download)..."
npx --yes prisma generate --no-engine 2>&1 | tail -5
echo ""

# ============================================
# 4. FIND RUNNER
# ============================================
WORKER="workers/sender.worker.ts"
echo "==============================================="
echo " 🚀 Starting worker..."
echo "==============================================="
echo ""

# Try methods
if [ -f "node_modules/.bin/tsx" ]; then
  echo "▶ Method 1: local tsx"
  exec ./node_modules/.bin/tsx "$WORKER"
elif [ -f "node_modules/tsx/dist/cli.mjs" ]; then
  echo "▶ Method 2: node + tsx cli"
  exec node node_modules/tsx/dist/cli.mjs "$WORKER"
else
  echo "▶ Method 3: npx tsx"
  exec npx --yes tsx@4.19.2 "$WORKER"
fi