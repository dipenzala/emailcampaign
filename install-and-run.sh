#!/usr/bin/env bash

echo "==============================================="
echo " 🚀 Polling Worker (BullMQ bypass)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ============================================
# ⚠️ APNI VALUES DAALO
# ============================================
export DATABASE_URL="postgresql://neondb_owner:npg_8gvTZDb7IWlX@ep-floral-violet-b41x9o5p-pooler.c-6.us-east-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
export REDIS_URL="rediss://default:XXX@selected-lion-308854.upstash.io:6379"
export GOOGLE_CLIENT_ID="402597624971-ugkvf8l5el7l9m84c8uglbuqap9fu29d.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="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"
export GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
export TOKEN_ENCRYPTION_KEY="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
export SESSION_SECRET="8a5880c2c17e072ec23a79da604e6f3ac1e60e88302d01bdd1844d80fe6ad62aad2f1cadc66ec63df1405f9e1188ae3a"
export APP_URL="https://emailcampaign-ten.vercel.app"
export NODE_ENV="production"
# ============================================

echo "✅ Env vars set"
echo ""

# Check tsx
if [ ! -f "node_modules/.bin/tsx" ] && [ ! -f "node_modules/tsx/dist/cli.mjs" ]; then
  echo "⚠️  tsx not found. Installing..."
  npm install --ignore-scripts tsx --silent
fi

echo "🚀 Starting polling worker..."
echo ""

# Run
if [ -f "node_modules/.bin/tsx" ]; then
  exec ./node_modules/.bin/tsx workers/polling-worker.ts
else
  exec node node_modules/tsx/dist/cli.mjs workers/polling-worker.ts
fi
