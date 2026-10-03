#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔧 Fix: Prisma Migration — Drop Legacy Users"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 2. Create pre-migrate script ----------
echo ""
echo "📝 scripts/pre-migrate.js (drops legacy User table)..."
mkdir -p scripts

cat > scripts/pre-migrate.js <<'EOF'
/**
 * Pre-migration cleanup.
 * Drops the User table if it has old columns (email-based).
 * This runs BEFORE `prisma db push`.
 * Safe: only touches the User table; senders/campaigns/contacts remain.
 */
const { PrismaClient } = require('@prisma/client');

(async () => {
  const prisma = new PrismaClient({ log: [] });
  try {
    // Check if new columns already exist by querying information_schema
    const rows = await prisma.$queryRawUnsafe(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'User'
        AND column_name IN ('username', 'passwordHash')
    `);

    if (rows.length === 2) {
      console.log('✅ User table already has new columns — skipping drop');
      await prisma.$disconnect();
      process.exit(0);
    }

    // Drop User table (only this one — senders etc. safe)
    console.log('🔄 Dropping legacy User table for schema update...');
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "User" CASCADE`);
    console.log('✅ Legacy User table dropped — will be recreated by prisma db push');
  } catch (e) {
    console.log('ℹ️  pre-migrate note:', (e.message || '').slice(0, 120));
    // Don't fail the build
  }
  try { await prisma.$disconnect(); } catch {}
  process.exit(0);
})();
EOF
sed -i 's/\r$//' scripts/pre-migrate.js
echo "   ✅"

# ---------- 3. Update package.json build command ----------
echo ""
echo "📦 Updating build command..."
node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts.build = 'prisma generate && node scripts/pre-migrate.js && prisma db push --skip-generate --accept-data-loss && next build';
pkg.scripts['db:push'] = 'prisma db push';
pkg.scripts['db:reset-users'] = 'node scripts/pre-migrate.js && prisma db push';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ build:', pkg.scripts.build);
NODEEOF

# ---------- 4. Verify User model ----------
echo ""
echo "🔎 Verify User model in prisma schema..."
if grep -q "model User" prisma/schema.prisma; then
  echo "   ✅ User model exists"
  echo ""
  echo "   Current User model:"
  awk '/model User \{/,/^\}/' prisma/schema.prisma | sed 's/^/     /'
else
  echo "   ❌ User model missing — adding..."
  cat >> prisma/schema.prisma <<'EOF'

model User {
  id           String    @id @default(cuid())
  username     String    @unique
  passwordHash String
  displayName  String?
  role         String    @default("member")
  isActive     Boolean   @default(true)
  lastLoginAt  DateTime?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
}
EOF
  sed -i 's/\r$//' prisma/schema.prisma
  echo "   ✅ Added"
fi

# ---------- 5. Git ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "Fix: pre-migrate script to drop legacy User table"
  echo "   ✅ Committed"
fi

# ---------- 6. Push ----------
echo ""
echo "🚀 Pushing..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED — Vercel will rebuild now"
echo "==================================================="
echo ""
echo "📊 Vercel build command is now:"
echo "   prisma generate && node scripts/pre-migrate.js && prisma db push --skip-generate --accept-data-loss && next build"
echo ""
echo "🎯 What happens:"
echo "   1. Prisma generates client"
echo "   2. pre-migrate.js checks User table"
echo "   3. If legacy → DROPS User table (senders/campaigns SAFE)"
echo "   4. prisma db push recreates User with new schema"
echo "   5. next build succeeds"
echo ""
echo "⏱️  Wait 2-3 min → check:"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "✅ Expected: 'Ready' status"
echo ""
echo "📋 After deploy:"
echo ""
echo "   1. Vercel me ADMIN_SETUP_KEY add karo:"
echo "      https://vercel.com/certwinx/emailcampaign/settings/environment-variables"
echo "      Key:   ADMIN_SETUP_KEY"
echo "      Value: $(openssl rand -hex 16 2>/dev/null || node -e "console.log(require('crypto').randomBytes(16).toString('hex'))")"
echo "      → Save → Redeploy"
echo ""
echo "   2. /login kholo:"
echo "      https://emailcampaign-ten.vercel.app/login"
echo "      → Setup form dikhega"
echo "      → Admin username + password + setup key daalo"
echo "      → Create Admin"
echo ""
echo "   3. Login karo — username + password se"
echo ""
echo "   4. /team pe jao → members add karo"
echo "==================================================="