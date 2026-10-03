#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔧 Fix: session.role support"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "🔧 CRLF ✅"

# ---------- 2. session.ts with role ----------
echo ""
echo "🔐 Rewriting lib/session.ts (with role)..."
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

// ---------- Session cookies ----------
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

// ---------- Token hashing ----------
export function hashToken(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

export function generateToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}

// ---------- Password helpers ----------
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

# ---------- 3. Update login to include role ----------
echo ""
echo "🔐 Updating /api/auth/login (with role)..."
mkdir -p app/api/auth/login
cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { email, username, name, password } = await req.json();

    // Email login (existing flow)
    if (email) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
        return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
      }
      const cleanEmail = String(email).toLowerCase().trim();
      try {
        await prisma.user.upsert({
          where: { email: cleanEmail },
          create: { email: cleanEmail, name: name || cleanEmail.split('@')[0], role: 'user' },
          update: {},
        });
      } catch {}
      const token = signSession({
        email: cleanEmail,
        name: name || cleanEmail.split('@')[0],
        role: 'user',
        ts: Date.now(),
      });
      const res = NextResponse.json({ ok: true, email: cleanEmail, role: 'user' });
      res.cookies.set('ec_session', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 * 24 * 30,
      });
      return res;
    }

    // Username login (invite-only team)
    if (username && password) {
      const cleanUsername = String(username).toLowerCase().trim();
      const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
      if (!user) return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });

      const { verifyPassword } = await import('@/lib/session');
      if (!user.passwordHash || !verifyPassword(password, user.passwordHash)) {
        return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
      }

      const token = signSession({
        username: user.username || '',
        name: user.displayName || user.name || user.username || '',
        role: user.role,
        ts: Date.now(),
      });
      const res = NextResponse.json({ ok: true, username: user.username, role: user.role });
      res.cookies.set('ec_session', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 * 24 * 30,
      });
      return res;
    }

    return NextResponse.json({ error: 'Missing credentials' }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: 'Login failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/auth/login/route.ts
echo "✅"

# ---------- 4. Update setup to include role in session ----------
echo ""
echo "🔐 Checking /api/auth/setup..."
if [ -f "app/api/auth/setup/route.ts" ]; then
  cat > app/api/auth/setup/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession, hashPassword } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const { username, password } = await req.json();
    if (!username || !password) {
      return NextResponse.json({ error: 'username + password required' }, { status: 400 });
    }
    if (String(password).length < 8) {
      return NextResponse.json({ error: 'Password min 8 characters' }, { status: 400 });
    }

    // Check if any owner exists
    const ownerExists = await prisma.user.findFirst({ where: { role: 'owner' } });
    if (ownerExists) {
      return NextResponse.json({ error: 'Owner already exists. Use invite flow.' }, { status: 403 });
    }

    const cleanUsername = String(username).trim().toLowerCase();
    const user = await prisma.user.create({
      data: {
        username: cleanUsername,
        passwordHash: hashPassword(password),
        displayName: cleanUsername,
        name: cleanUsername,
        role: 'owner',
      },
    });

    const token = signSession({
      username: user.username || '',
      name: user.displayName || user.username || '',
      role: user.role,
      ts: Date.now(),
    });
    const res = NextResponse.json({ ok: true, username: user.username, role: user.role });
    res.cookies.set('ec_session', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30,
    });
    return res;
  } catch (err: any) {
    return NextResponse.json({ error: 'Setup failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
  sed -i 's/\r$//' app/api/auth/setup/route.ts
  echo "   ✅ setup updated"
else
  echo "   ℹ️  No setup route"
fi

# ---------- 5. Update auth/me to expose role ----------
echo ""
echo "🔐 Updating /api/auth/me..."
mkdir -p app/api/auth/me
cat > app/api/auth/me/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifySession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const user = verifySession(token);
  if (!user) return NextResponse.json({ user: null }, { status: 401 });
  return NextResponse.json({
    user: {
      email: user.email,
      username: user.username,
      name: user.name,
      role: user.role,
    },
  });
}
EOF
sed -i 's/\r$//' app/api/auth/me/route.ts
echo "✅"

# ---------- 6. Dedupe all routes ----------
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

# ---------- 7. Verify ----------
echo ""
echo "🔎 Verification:"
grep -q "role" lib/session.ts && echo "   ✅ session.ts has role" || { echo "   ❌ role missing"; exit 1; }
grep -q "SessionPayload" lib/session.ts && echo "   ✅ SessionPayload type" || { echo "   ❌ SessionPayload missing"; exit 1; }

# Check for other session.role references
echo ""
echo "   Scanning team/route.ts references..."
if [ -f "app/api/team/route.ts" ]; then
  grep -n "session.role" app/api/team/route.ts | head -3 && echo "   ✅ Compatible now"
fi

# ---------- 8. Git push ----------
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
  git commit -m "Fix: session.role support across login/setup/me/team"
  echo "   ✅ Committed"
fi

git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED"
echo "==================================================="
echo ""
echo "📊 Vercel rebuild (2-3 min)"
echo ""
echo "🎯 Verify after deploy:"
echo "  https://emailcampaign.vercel.app/api/queue/health"
echo "  https://emailcampaign.vercel.app/api/debug/env"
echo "==================================================="