#!/usr/bin/env bash

echo "==============================================="
echo " 🔧 Regenerate Prisma Client (with engine)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Load .env if exists
# ==========================================
if [ -f ".env" ]; then
  echo "📝 Loading .env..."
  set -a
  source .env
  set +a
  echo "   ✅ Loaded"
else
  echo "⚠️  .env nahi mila — placeholders use kar rahe hain"
fi
echo ""

# Validate DATABASE_URL
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?:// ]]; then
  echo "❌ DATABASE_URL galat hai!"
  echo "   Value: ${DATABASE_URL:0:60}..."
  echo ""
  echo "   'postgresql://' se start honi chahiye."
  echo "   Check karo: cat .env"
  exit 1
fi
echo "✅ DATABASE_URL looks OK: ${DATABASE_URL:0:40}..."
echo ""

# ==========================================
# 2. Delete broken client
# ==========================================
echo "🧹 Deleting broken Prisma client..."
rm -rf node_modules/.prisma 2>/dev/null || true
rm -rf node_modules/@prisma/client 2>/dev/null || true
echo "   ✅ Deleted"
echo ""

# ==========================================
# 3. Reinstall @prisma/client
# ==========================================
echo "📦 Reinstalling @prisma/client..."
npm install --ignore-scripts @prisma/client@5.22.0 --silent 2>&1 | tail -3
echo "   ✅ Done"
echo ""

# ==========================================
# 4. Generate with engine (via mirror to avoid TLS issues)
# ==========================================
echo "🔧 Generating Prisma Client (with engine)..."

# Try 1: Normal
echo "▶  Attempt 1: Normal generate"
if npx --yes prisma@5.22.0 generate 2>&1 | tail -5; then
  echo "   ✅ Success"
  GENERATED=1
else
  echo "   ⚠️  Failed, trying mirror..."
  GENERATED=0
fi

# Try 2: Mirror
if [ "$GENERATED" -eq 0 ]; then
  echo "▶  Attempt 2: With China mirror"
  export PRISMA_ENGINES_MIRROR="https://registry.npmmirror.com/-/binary/prisma"
  if npx --yes prisma@5.22.0 generate 2>&1 | tail -5; then
    echo "   ✅ Success"
    GENERATED=1
  fi
fi

# Try 3: Mirror 2
if [ "$GENERATED" -eq 0 ]; then
  echo "▶  Attempt 3: Different mirror"
  export PRISMA_ENGINES_MIRROR="https://binaries.prisma.sh"
  if npx --yes prisma@5.22.0 generate 2>&1 | tail -5; then
    echo "   ✅ Success"
    GENERATED=1
  fi
fi

if [ "$GENERATED" -eq 0 ]; then
  echo ""
  echo "╔═══════════════════════════════════════════╗"
  echo "║  ❌ Engine download failed (TLS)          ║"
  echo "╚═══════════════════════════════════════════╝"
  echo ""
  echo "Prisma engine download nahi ho paaya."
  echo ""
  echo "Alternative: Polling worker use karo (jo bina Prisma engine chalta hai)"
  echo ""
  echo "  bash run-polling.sh"
  echo ""
  exit 1
fi

# ==========================================
# 5. Verify
# ==========================================
echo ""
echo "🔎 Verification:"
if [ -d "node_modules/.prisma/client" ]; then
  echo "   ✅ Client generated at node_modules/.prisma/client"
else
  echo "   ❌ Client not found"
  exit 1
fi

# ==========================================
# 6. Test connection
# ==========================================
echo ""
echo "🔌 Testing DB connection..."
node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  try {
    const c = await p.campaign.count();
    console.log("   ✅ DB connected, " + c + " campaigns in DB");
  } catch (e) {
    console.error("   ❌ DB error: " + e.message.slice(0, 100));
    process.exit(1);
  }
  await p.$disconnect();
})();
' 2>&1

echo ""
echo "==============================================="
echo " ✅ Prisma client regenerated!"
echo "==============================================="
echo ""
echo "🎯 Ab worker chalao:"
echo "   bash install-and-run.sh"
echo ""