#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🚀 EmailCampaign — Push Final"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF fix ----------
echo ""
echo "🔧 Line endings..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅"

# ---------- 2. Prisma schema (proper multi-line) ----------
echo ""
echo "📝 prisma/schema.prisma..."
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
echo "✅"

# ---------- 3. package.json ----------
echo ""
echo "📦 package.json..."
node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));

pkg.dependencies = pkg.dependencies || {};
pkg.devDependencies = pkg.devDependencies || {};

// Move runtime deps
["tsx", "typescript", "prisma"].forEach(p => {
  if (pkg.devDependencies[p]) {
    pkg.dependencies[p] = pkg.devDependencies[p];
    delete pkg.devDependencies[p];
  }
});

// Pin bullmq (avoid valkey-glide import)
pkg.dependencies["bullmq"] = "^5.28.0";

// Disable postinstall (network issue with Prisma CDN)
pkg.scripts = pkg.scripts || {};
pkg.scripts.postinstall = "echo skipping-postinstall";

// Build command for Vercel (with DB push)
pkg.scripts.build = "prisma generate && prisma db push --skip-generate --accept-data-loss && next build";

// Other scripts
pkg.scripts.worker = "tsx workers/sender.worker.ts";
pkg.scripts["db:push"] = "prisma db push";
pkg.scripts.dev = "concurrently -n next,worker -c cyan,magenta \"next dev -p 3000\" \"tsx watch workers/sender.worker.ts\"";
pkg.scripts.start = "concurrently -n next,worker -c cyan,magenta \"next start -p 3000\" \"tsx workers/sender.worker.ts\"";

fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
console.log("   ✅ deps moved, scripts set");
console.log("   ✅ build: prisma generate && prisma db push && next build");
'
echo "✅"

# ---------- 4. Procfile + gitattributes + gitignore ----------
echo ""
printf "worker: npm run worker\n" > Procfile
sed -i 's/\r$//' Procfile

cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
Procfile text eol=lf
*.prisma text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.json text eol=lf
*.css text eol=lf
EOF
sed -i 's/\r$//' .gitattributes

if [ ! -f ".gitignore" ] || ! grep -q node_modules .gitignore; then
cat > .gitignore <<'EOF'
node_modules/
.next/
out/
build/
dist/
.env
.env.local
.env*.local
.env.production
*.db
*.log
.vscode/
.idea/
.DS_Store
.vercel
next-env.d.ts
EOF
sed -i 's/\r$//' .gitignore
fi
echo "✅ Procfile + .gitattributes + .gitignore"

# ---------- 5. Verify Prisma schema format ----------
echo ""
echo "🔎 Prisma schema format check..."
if head -5 prisma/schema.prisma | grep -q "^generator client {$"; then
  echo "✅ Multi-line format OK"
else
  echo "⚠️  Format needs review:"
  head -8 prisma/schema.prisma
fi

# ---------- 6. Git ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi

REPO_URL="https://github.com/dipenzala/emailcampaign.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

# Untrack .env
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  git rm --cached .env >/dev/null 2>&1 || true
fi

# Author (Vercel-safe)
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

# ---------- 7. Commit ----------
echo ""
git add -A
if git diff --cached --quiet; then
  echo "ℹ️  No changes to commit"
else
  git commit -m "Fix: Prisma schema + build script + postinstall skip"
  echo "✅ Committed"
fi

# ---------- 8. Push ----------
echo ""
echo "🚀 Pushing to GitHub..."
git push -u origin main

# ---------- 9. Summary ----------
echo ""
echo "==================================================="
echo " ✅ PUSHED SUCCESSFULLY"
echo "==================================================="
echo ""
echo "📊 Vercel auto-rebuild shuru ho gaya:"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "⏱️  Wait karo 2-3 minute. Build logs me ye dikhna chahiye:"
echo ""
echo "   Running \"prisma generate && prisma db push --skip-generate --accept-data-loss && next build\""
echo "   ✔ Generated Prisma Client"
echo "   🚀  Your database is now in sync with your Prisma schema."
echo "   ✔ Compiled successfully"
echo "   ✅ Deployment ready"
echo ""
echo "🎯 Success ke baad test karo:"
echo "   /          → Landing"
echo "   /login     → Login"
echo "   /dashboard → Protected dashboard"
echo ""
echo "⚠️  Agar build me koi error aaye — screenshot bhejo."
echo "==================================================="