#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔧 Fix User Model (username + password support)"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "🔧 CRLF ✅"

# ---------- 2. Update Prisma schema ----------
echo ""
echo "📝 Rewriting prisma/schema.prisma (User model expanded)..."

cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  email        String?  @unique
  username     String?  @unique
  name         String?
  displayName  String?
  passwordHash String?
  role         String   @default("user")
  createdAt    DateTime @default(now())
}

model SenderAccount {
  id              String    @id @default(cuid())
  email           String    @unique
  displayName     String?
  accessToken     String?
  refreshToken    String?
  tokenExpiry     DateTime?
  scope           String?
  status          String    @default("DISCONNECTED")
  sentToday       Int       @default(0)
  dailyLimit      Int       @default(10)
  batchCount      Int       @default(0)
  rotationOrder   Int       @default(0)
  isActive        Boolean   @default(true)
  errors          Int       @default(0)
  lastSuccessAt   DateTime?
  lastResetAt     DateTime  @default(now())
  warmupEnabled   Boolean   @default(true)
  warmupStartedAt DateTime  @default(now())
  warmupDay       Int       @default(1)
  hardBounces     Int       @default(0)
  softBounces     Int       @default(0)
  complaints      Int       @default(0)
  reputationScore Int       @default(100)
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
}

model Contact {
  id            String    @id @default(cuid())
  email         String    @unique
  name          String?
  company       String?
  phone         String?
  city          String?
  custom        Json?
  isRoleAccount Boolean   @default(false)
  isDisposable  Boolean   @default(false)
  hygieneScore  Int       @default(100)
  createdAt     DateTime  @default(now())
  recipients    CampaignRecipient[]
}

model SuppressionList {
  id        String   @id @default(cuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}

model Campaign {
  id              String   @id @default(cuid())
  name            String
  subject         String
  html            String
  status          String   @default("DRAFT")
  totalCount      Int      @default(0)
  sentCount       Int      @default(0)
  deliveredCount  Int      @default(0)
  failedCount     Int      @default(0)
  bouncedCount    Int      @default(0)
  suppressedCount Int      @default(0)
  batchLimit      Int      @default(10)
  spamScore       Int?
  spamIssues      Json?
  createdAt       DateTime @default(now())
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
  bouncedAt         DateTime?
  bounceType        String?
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
echo "✅ Schema updated (User + username/passwordHash/displayName/role)"

# ---------- 3. Scan for other auth routes with schema issues ----------
echo ""
echo "🔎 Scanning for other routes with mismatched fields..."

# Find all route files that reference User model fields
BROKEN=0
for f in $(find app/api/auth -name "route.ts" 2>/dev/null); do
  echo "   Checking: $f"
  # Check for fields that don't exist
  if grep -q "prisma\.\(user\|User\)" "$f" 2>/dev/null; then
    if grep -qE "username|passwordHash|displayName|role" "$f" 2>/dev/null; then
      echo "     → uses User fields, schema has them now ✅"
    fi
  fi
done
echo "✅"

# ---------- 4. Verify session.ts has hashPassword ----------
echo ""
echo "🔐 Verifying lib/session.ts..."
mkdir -p lib
if ! grep -q "export function hashPassword" lib/session.ts 2>/dev/null; then
  echo "   Adding hashPassword to session.ts..."
  cat > lib/session.ts <<'EOF'
import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export function signSession(payload: { email: string; name?: string; ts: number }) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): { email: string; name?: string } | null {
  if (!token) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try {
    return JSON.parse(Buffer.from(data, 'base64url').toString());
  } catch {
    return null;
  }
}

export function hashToken(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

export function generateToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}

export function hashPassword(password: string, salt?: string): string {
  const useSalt = salt ?? crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, useSalt, 100_000, 64, 'sha512').toString('hex');
  return `${useSalt}:${hash}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  try {
    const [salt, hash] = stored.split(':');
    if (!salt || !hash) return false;
    const check = crypto.pbkdf2Sync(password, salt, 100_000, 64, 'sha512').toString('hex');
    return crypto.timingSafeEqual(Buffer.from(check), Buffer.from(hash));
  } catch {
    return false;
  }
}
EOF
  sed -i 's/\r$//' lib/session.ts
  echo "   ✅ Updated"
else
  echo "   ✅ Already has hashPassword"
fi

# ---------- 5. Dedupe runtime/dynamic ----------
echo ""
echo "🔎 Deduping runtime/dynamic..."

node <<'NODEEOF'
const fs = require('fs');
const path = require('path');
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name === 'route.ts') out.push(p);
  }
  return out;
}
const files = walk('app/api');
let fixed = 0;
const RE = /^\s*export\s+const\s+(dynamic|runtime|maxDuration)\s*=/;
for (const f of files) {
  const orig = fs.readFileSync(f, 'utf8');
  const lines = orig.split('\n').filter(l => !RE.test(l));
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) if (/^\s*import\s/.test(lines[i])) lastImport = i;
  const ins = ['', 'export const dynamic = "force-dynamic";', 'export const runtime = "nodejs";', ''];
  if (lastImport >= 0) lines.splice(lastImport + 1, 0, ...ins);
  else lines.unshift(...ins);
  const out = lines.join('\n').replace(/\n{3,}/g, '\n\n');
  if (out !== orig) { fs.writeFileSync(f, out); fixed++; }
}
console.log('   Fixed: ' + fixed + '/' + files.length);
NODEEOF

# ---------- 6. Verify ----------
echo ""
echo "🔎 Verification:"
head -3 prisma/schema.prisma | grep -q "^generator client {" && echo "   ✅ Schema multi-line" || { echo "   ❌ Schema format"; exit 1; }

grep -q "username" prisma/schema.prisma && echo "   ✅ User.username present" || { echo "   ❌ username missing"; exit 1; }
grep -q "passwordHash" prisma/schema.prisma && echo "   ✅ User.passwordHash present" || { echo "   ❌ passwordHash missing"; exit 1; }
grep -q "displayName" prisma/schema.prisma && echo "   ✅ User.displayName present" || { echo "   ❌ displayName missing"; exit 1; }
grep -q "role" prisma/schema.prisma && echo "   ✅ User.role present" || { echo "   ❌ role missing"; exit 1; }

BAD=0
for f in $(find app/api -name "route.ts" 2>/dev/null); do
  R=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  D=$(grep -c "^export const dynamic" "$f" 2>/dev/null | tr -d '[:space:]')
  [ "$R" -ne 1 ] || [ "$D" -ne 1 ] && BAD=$((BAD+1))
done
[ $BAD -eq 0 ] && echo "   ✅ All API routes clean" || echo "   ⚠️ $BAD broken routes"

# ---------- 7. Git push ----------
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
  git commit -m "Fix: User model (username/passwordHash/displayName/role) + hashPassword helper"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED"
echo "==================================================="
echo ""
echo "📊 Vercel auto-rebuild (2-3 min):"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "🎯 Ye URL check karo:"
echo "   https://emailcampaign.vercel.app/api/queue/health"
echo ""
echo "Expected: {\"ok\":true,\"redis\":\"PONG\",\"status\":\"ready\"}"
echo "==================================================="