#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔧 Fix Prisma Schema + Push"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. Multi-line Prisma schema ----------
echo ""
echo "📝 Rewriting prisma/schema.prisma (proper multi-line)..."
mkdir -p prisma

cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
}

model SenderAccount {
  id            String    @id @default(cuid())
  email         String    @unique
  displayName   String?
  accessToken   String?
  refreshToken  String?
  tokenExpiry   DateTime?
  scope         String?
  status        String    @default("DISCONNECTED")
  sentToday     Int       @default(0)
  errors        Int       @default(0)
  lastSuccessAt DateTime?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

model Contact {
  id         String              @id @default(cuid())
  email      String              @unique
  name       String?
  company    String?
  phone      String?
  city       String?
  custom     Json?
  createdAt  DateTime            @default(now())
  recipients CampaignRecipient[]
}

model SuppressionList {
  id        String   @id @default(cuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}

model Campaign {
  id              String              @id @default(cuid())
  name            String
  subject         String
  html            String
  status          String              @default("DRAFT")
  totalCount      Int                 @default(0)
  sentCount       Int                 @default(0)
  deliveredCount  Int                 @default(0)
  failedCount     Int                 @default(0)
  bouncedCount    Int                 @default(0)
  suppressedCount Int                 @default(0)
  createdAt       DateTime            @default(now())
  startedAt       DateTime?
  completedAt     DateTime?
  recipients      CampaignRecipient[]
}

model CampaignRecipient {
  id                String    @id @default(cuid())
  campaignId        String
  contactId         String
  senderAccountId   String?
  status            String    @default("QUEUED")
  providerMessageId String?
  errorCode         String?
  errorMessage      String?
  attemptCount      Int       @default(0)
  queuedAt          DateTime  @default(now())
  sentAt            DateTime?
  deliveredAt       DateTime?
  failedAt          DateTime?
  campaign          Campaign  @relation(fields: [campaignId], references: [id], onDelete: Cascade)
  contact           Contact   @relation(fields: [contactId], references: [id])

  @@unique([campaignId, contactId])
  @@index([campaignId, status])
}

model MessageLog {
  id          String   @id @default(cuid())
  campaignId  String
  recipientId String
  level       String
  message     String
  createdAt   DateTime @default(now())
}

model AuditLog {
  id        String   @id @default(cuid())
  action    String
  meta      Json?
  createdAt DateTime @default(now())
}
PRISMA

sed -i 's/\r$//' prisma/schema.prisma
echo "✅ schema.prisma rewritten"

# ---------- 2. Verify no CRLF, no single-line blocks ----------
echo ""
echo "🔍 Checking format..."
if grep -q 'generator client {' prisma/schema.prisma && \
   grep -q '^  provider = "prisma-client-js"' prisma/schema.prisma && \
   grep -q '^}' prisma/schema.prisma; then
  echo "✅ Multi-line format OK"
else
  echo "⚠️  Format check needs manual review"
fi

# Show first 12 lines
echo ""
echo "--- First 12 lines ---"
head -12 prisma/schema.prisma
echo "--- End ---"

# ---------- 3. Git ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi

REPO_URL="https://github.com/dipenzala/emailcampaign.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "ℹ️  No changes."
else
  git commit -m "Fix: Prisma schema proper multi-line format"
  echo "✅ Committed"
fi

echo ""
echo "🚀 Pushing..."
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED"
echo "==================================================="
echo ""
echo "📊 Vercel auto-rebuild shuru hoga (2-3 min):"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "⚠️  NEON DB PUSH abhi karo:"
echo ""
echo "  export DATABASE_URL='postgresql://neondb_owner:npg_XXX@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require'"
echo "  npx prisma db push"
echo ""
echo "Neon URL: https://console.neon.tech → Connection String → Prisma"
echo "==================================================="