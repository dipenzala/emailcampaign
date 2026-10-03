#!/usr/bin/env bash

echo "==============================================="
echo " 🚀 Local Worker — Starting..."
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ============================================
# 1. ENV VARS — EDIT KARO APNI VALUES
# ============================================
echo "🔧 Setting environment variables..."

export DATABASE_URL="postgresql://neondb_owner:npg_XXX@ep-xxx-pooler.c-6.us-east-2.aws.neon.tech/neondb?sslmode=require"
export REDIS_URL="rediss://default:XXX@selected-lion-308854.upstash.io:6379"
export GOOGLE_CLIENT_ID="xxx.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-xxx"
export GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
export TOKEN_ENCRYPTION_KEY="f371f9f48cc14371b941f26f23afe6d37462b143b48187457a2ea0eb642ade02"
export SESSION_SECRET="8a5880c2c17e072ec23a79da604e6f3ac1e60e88302d01bdd1844d80fe6ad62aad2f1cadc66ec63df1405f9e1188ae3a"
export APP_URL="https://emailcampaign-ten.vercel.app"
export NODE_ENV="production"

# Show what's set (masked)
echo "  DATABASE_URL: $(echo $DATABASE_URL | cut -c1-50)..."
echo "  REDIS_URL:    $(echo $REDIS_URL | cut -c1-50)..."
echo "  APP_URL:      $APP_URL"
echo ""

# ============================================
# 2. CHECK WORKER FILE
# ============================================
if [ ! -f "workers/sender.worker.ts" ]; then
  echo "❌ workers/sender.worker.ts not found!"
  exit 1
fi
echo "✅ worker file exists"
echo ""

# ============================================
# 3. FIND WORKING RUNNER — 4 methods
# ============================================
echo "🔍 Finding working tsx runner..."
echo ""

WORKER="workers/sender.worker.ts"

# ---- Method 1: Local binary ----
if [ -f "node_modules/.bin/tsx" ]; then
  echo "✅ Method 1: Local binary (node_modules/.bin/tsx)"
  echo ""
  echo "==============================================="
  echo " 🚀 Starting worker..."
  echo "==============================================="
  echo ""
  exec ./node_modules/.bin/tsx "$WORKER"
fi

# ---- Method 2: tsx cli.mjs via node ----
if [ -f "node_modules/tsx/dist/cli.mjs" ]; then
  echo "✅ Method 2: Node + tsx/cli.mjs"
  echo ""
  echo "==============================================="
  echo " 🚀 Starting worker..."
  echo "==============================================="
  echo ""
  exec node node_modules/tsx/dist/cli.mjs "$WORKER"
fi

# ---- Method 3: Global tsx ----
if command -v tsx >/dev/null 2>&1; then
  echo "✅ Method 3: Global tsx"
  echo ""
  echo "==============================================="
  echo " 🚀 Starting worker..."
  echo "==============================================="
  echo ""
  exec tsx "$WORKER"
fi

# ---- Method 4: Install tsx then run ----
echo "⚠️  tsx not found. Installing..."
echo ""

# Try local install first (no admin needed)
if npm install tsx --no-save --silent 2>&1 | tail -3; then
  if [ -f "node_modules/.bin/tsx" ]; then
    echo "✅ Installed locally"
    echo ""
    echo "==============================================="
    echo " 🚀 Starting worker..."
    echo "==============================================="
    echo ""
    exec ./node_modules/.bin/tsx "$WORKER"
  fi
fi

# Last resort: npx
echo "⚠️  Trying npx as last resort..."
echo ""
echo "==============================================="
echo " 🚀 Starting worker..."
echo "==============================================="
echo ""
exec npx --yes tsx@4.19.2 "$WORKER"