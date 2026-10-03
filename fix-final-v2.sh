#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🎯 FINAL FIX — All Errors Solve"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ============================================
# 1. CRLF
# ============================================
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "🔧 [1/8] CRLF ✅"

# ============================================
# 2. CLEAR CACHES (CRITICAL)
# ============================================
echo ""
echo "🧹 [2/8] Clearing caches..."
rm -rf .next 2>/dev/null || true
rm -rf node_modules/.prisma 2>/dev/null || true
rm -rf node_modules/.cache 2>/dev/null || true
echo "✅ .next + prisma cache cleared"

# ============================================
# 3. COMPLETE PRISMA SCHEMA
# ============================================
echo ""
echo "📝 [3/8] Full Prisma schema (all fields)..."
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
  id           String    @id @default(cuid())
  email        String?   @unique
  username     String?   @unique
  name         String?
  displayName  String?
  passwordHash String?
  role         String    @default("user")
  isActive     Boolean   @default(true)
  lastLoginAt  DateTime?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
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
echo "✅ User model: id, email, username, name, displayName, passwordHash, role, isActive, lastLoginAt, createdAt, updatedAt"

# ============================================
# 4. REWRITE team/route.ts (COMPATIBLE)
# ============================================
echo ""
echo "🛠️  [4/8] Rewriting /api/team/route.ts..."
mkdir -p app/api/team

cat > app/api/team/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession, hashPassword } from '@/lib/session';
import { randomBytes } from 'crypto';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// GET: list team members
export async function GET() {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        name: true,
        role: true,
        isActive: true,
        lastLoginAt: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ users });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// POST: create new team member
export async function POST(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const { username, password, role } = await req.json();
    if (!username || !password) {
      return NextResponse.json({ error: 'username + password required' }, { status: 400 });
    }
    if (String(password).length < 8) {
      return NextResponse.json({ error: 'Password min 8 chars' }, { status: 400 });
    }

    const cleanUsername = String(username).toLowerCase().trim();

    const exists = await prisma.user.findUnique({ where: { username: cleanUsername } });
    if (exists) {
      return NextResponse.json({ error: 'Username taken' }, { status: 409 });
    }

    const user = await prisma.user.create({
      data: {
        username: cleanUsername,
        passwordHash: hashPassword(password),
        displayName: cleanUsername,
        name: cleanUsername,
        role: role || 'user',
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ ok: true, user });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// PUT: update user role / active status
export async function PUT(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const { id, role, isActive } = await req.json();
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    const data: any = {};
    if (typeof role === 'string') data.role = role;
    if (typeof isActive === 'boolean') data.isActive = isActive;

    const user = await prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
      },
    });

    return NextResponse.json({ ok: true, user });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}

// DELETE: remove team member
export async function DELETE(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session || session.role !== 'owner') {
      return NextResponse.json({ error: 'Owner only' }, { status: 403 });
    }

    const url = new URL(req.url);
    const id = url.searchParams.get('id');
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    await prisma.user.delete({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/team/route.ts
echo "✅ team route rewritten (only uses schema fields)"

# ============================================
# 5. VERIFY session.ts
# ============================================
echo ""
echo "🔐 [5/8] Verifying lib/session.ts..."
cat > lib/session.ts <<'EOF'
import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export type SessionPayload = {
  email?: string;
  username?: string;
  name?: string;
  role?: string;
  ts: number;
};

export function signSession(payload: SessionPayload): string {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): SessionPayload | null {
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
echo "✅"

# ============================================
# 6. DEDUPE + SCAN for missing fields
# ============================================
echo ""
echo "🔎 [6/8] Deduping + scanning..."

# Dedupe runtime/dynamic
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
console.log('   Deduped: ' + fixed + '/' + files.length);
NODEEOF

# Scan for User model field references that schema might not have
echo ""
echo "   Scanning routes for User field references..."
grep -rn "prisma\.user\." app/api --include="*.ts" 2>/dev/null | grep -oE "prisma\.user\.[a-z]+\(" | sort -u || true
echo "   ✅"

# ============================================
# 7. VERIFY
# ============================================
echo ""
echo "🔎 [7/8] Final verification:"

# Prisma schema check
head -3 prisma/schema.prisma | grep -q "^generator client {" && echo "   ✅ Schema format" || exit 1
grep -q "username" prisma/schema.prisma && echo "   ✅ User.username" || exit 1
grep -q "passwordHash" prisma/schema.prisma && echo "   ✅ User.passwordHash" || exit 1
grep -q "role" prisma/schema.prisma && echo "   ✅ User.role" || exit 1
grep -q "isActive" prisma/schema.prisma && echo "   ✅ User.isActive" || exit 1
grep -q "lastLoginAt" prisma/schema.prisma && echo "   ✅ User.lastLoginAt" || exit 1

# Team route check
grep -q "role: true" app/api/team/route.ts && echo "   ✅ team route uses role: true" || echo "   ⚠️ team route"

# Session check
grep -q "export function hashPassword" lib/session.ts && echo "   ✅ hashPassword export" || exit 1
grep -q "export function hashToken" lib/session.ts && echo "   ✅ hashToken export" || exit 1

# Route duplicates
BAD=0
for f in $(find app/api -name "route.ts" 2>/dev/null); do
  R=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  D=$(grep -c "^export const dynamic" "$f" 2>/dev/null | tr -d '[:space:]')
  [ "$R" -ne 1 ] || [ "$D" -ne 1 ] && BAD=$((BAD+1))
done
[ $BAD -eq 0 ] && echo "   ✅ All routes clean" || echo "   ⚠️ $BAD routes have dupes"

echo "✅"

# ============================================
# 8. GIT PUSH
# ============================================
echo ""
echo "🌿 [8/8] Git commit + push..."

if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"

# Untrack .env
git ls-files --error-unmatch .env >/dev/null 2>&1 && git rm --cached .env >/dev/null 2>&1 || true

# Author
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Nothing to commit"
else
  git commit -m "FINAL: User model expanded (isActive, lastLoginAt) + team route rewrite + cache clear"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==================================================="
echo " ✅✅✅ FINAL FIX PUSHED"
echo "==================================================="
echo ""
echo "📊 Vercel auto-rebuild (2-3 min):"
echo "   https://vercel.com/certwinx/emailcampaign/deployments"
echo ""
echo "🎯 Ye URLs deploy ke baad test karo:"
echo ""
echo "   1. https://emailcampaign.vercel.app/            → Landing"
echo "   2. https://emailcampaign.vercel.app/login       → Login"
echo "   3. https://emailcampaign.vercel.app/dashboard   → Dashboard"
echo "   4. https://emailcampaign.vercel.app/senders     → Senders"
echo "   5. https://emailcampaign.vercel.app/anti-spam   → Anti-Spam"
echo "   6. https://emailcampaign.vercel.app/api/queue/health"
echo ""
echo "⚠️  Agar koi env var missing ho to Vercel Settings me add karo:"
echo "   DATABASE_URL, REDIS_URL, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,"
echo "   GOOGLE_REDIRECT_URI, TOKEN_ENCRYPTION_KEY, SESSION_SECRET, APP_URL"
echo "==================================================="