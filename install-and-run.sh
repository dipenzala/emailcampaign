#!/usr/bin/env bash

echo "==============================================="
echo " 🚀 NEVER-STOP WORKER"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

set -a
source .env
set +a

echo "✅ .env loaded"
echo ""

# Ensure tsx
if [ ! -f "node_modules/.bin/tsx" ] && [ ! -f "node_modules/tsx/dist/cli.mjs" ]; then
  echo "⚠️  Installing tsx..."
  npm install --ignore-scripts tsx --silent 2>&1 | tail -2
fi

echo "🚀 Starting auto-runner..."
echo ""

# Start
if [ -f "node_modules/.bin/tsx" ]; then
  exec ./node_modules/.bin/tsx workers/auto-runner.ts
elif [ -f "node_modules/tsx/dist/cli.mjs" ]; then
  exec node node_modules/tsx/dist/cli.mjs workers/auto-runner.ts
else
  exec npx --yes tsx@4.19.2 workers/auto-runner.ts
fi
