#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🧹 Clean Stray Files + Fix Session"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. Delete stray folders ----------
echo ""
echo "🧹 Removing stray files..."

# Delete account/sessions route (not part of our app)
rm -rf app/api/account 2>/dev/null && echo "   ✅ Removed app/api/account/"
rm -rf app/api/sessions 2>/dev/null

# Delete stray scripts folder
rm -rf scripts 2>/dev/null && echo "   ✅ Removed scripts/"
rm -f pre-migrate.js prebuild.js 2>/dev/null

echo "✅ Stray files cleaned"

# ---------- 2. Ensure session.ts exports full API ----------
echo ""
echo "📝 lib/session.ts (with hashToken + verifyToken)..."
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

// Additional helpers (in case any code imports them)
export function hashToken(token: string): string {
  return crypto.createHmac('sha256', SECRET).update(token).digest('hex');
}

export function verifyToken(token: string, hash: string): boolean {
  return hashToken(token) === hash;
}

export function randomToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}
EOF
sed -i 's/\r$//' lib/session.ts
echo "✅"

# ---------- 3. Verify no other stray imports ----------
echo ""
echo "🔎 Checking for missing imports in api routes..."

node <<'NODEEOF'
const fs = require('fs');
const path = require('path');
const ROOT = 'app/api';

function walk(dir, out=[]) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.ts') || e.name.endsWith('.tsx')) out.push(p);
  }
  return out;
}

const files = walk(ROOT);
let issues = 0;
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  // Check for imports from lib/session
  const m = src.match(/import\s*\{([^}]+)\}\s*from\s*['"]@\/lib\/session['"]/);
  if (m) {
    const imports = m[1].split(',').map(s => s.trim());
    const allowed = ['signSession', 'verifySession', 'hashToken', 'verifyToken', 'randomToken'];
    const bad = imports.filter(i => !allowed.includes(i));
    if (bad.length) {
      console.log(`   ❌ ${f} imports unknown: ${bad.join(', ')}`);
      issues++;
    }
  }
  // Check for @/lib/queue imports
  const q = src.match(/import\s*\{([^}]+)\}\s*from\s*['"]@\/lib\/queue['"]/);
  if (q) {
    const imports = q[1].split(',').map(s => s.trim());
    const allowed = ['SEND_QUEUE', 'QUEUE_PREFIX', 'sendQueue', 'getSendQueue'];
    const bad = imports.filter(i => !allowed.includes(i));
    if (bad.length) {
      console.log(`   ❌ ${f} imports unknown from queue: ${bad.join(', ')}`);
      issues++;
    }
  }
}
if (issues === 0) console.log('   ✅ All imports valid');
else console.log(`   ⚠️  ${issues} issue(s) — fix manually`);
NODEEOF

# ---------- 4. Fix package.json ----------
echo ""
echo "📦 package.json — clean stray scripts..."
node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
pkg.scripts = pkg.scripts || {};
// Ensure build doesn't reference pre-migrate
pkg.scripts.build = "prisma generate && prisma db push --skip-generate --accept-data-loss && next build";
pkg.scripts.postinstall = "echo skipping-postinstall";
// Remove any stray references
delete pkg.scripts.premigrate;
delete pkg.scripts["pre-migrate"];
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
console.log("   ✅ Build:", pkg.scripts.build);
'
echo "✅"

# ---------- 5. Show what will be committed ----------
echo ""
echo "📊 Git status:"
git add -A
git status --short | head -20

# ---------- 6. Commit + push ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

if git diff --cached --quiet; then
  echo "ℹ️  Nothing to commit"
else
  git commit -m "Clean: remove stray account/sessions + scripts + full session API"
  echo "✅ Committed"
fi

git push -u origin main

echo ""
echo "==================================================="
echo " ✅ Cleaned and pushed"
echo "==================================================="
echo ""
echo "🚨 IMPORTANT — Vercel build command fix karo MANUALLY:"
echo ""
echo "1. Kholo: https://vercel.com/certwinx/emailcampaign-ten/settings"
echo "2. 'Build & Development Settings' section"
echo "3. Build Command me ye daalo (EXACT):"
echo ""
echo "   prisma generate && prisma db push --skip-generate --accept-data-loss && next build"
echo ""
echo "4. Save → Redeploy"
echo ""
echo "⚠️  'node scripts/pre-migrate.js' HATA DO — hum wo file use nahi karte"
echo "==================================================="