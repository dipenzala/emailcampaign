#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 👥 DEFAULT SENDER NAME — Startup Team"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. UPDATE OAUTH CALLBACK — auto set name
# ==========================================
echo "🔐 [1/4] Updating OAuth callback..."

mkdir -p app/api/oauth/google/callback

cat > app/api/oauth/google/callback/route.ts <<'EOF'
import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const DEFAULT_DISPLAY_NAME = 'Startup Team';

export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const appUrl = process.env.APP_URL || url.origin;

  if (error) return NextResponse.json({ error: 'Google error', detail: error }, { status: 400 });
  if (!code) return NextResponse.json({ error: 'Missing code' }, { status: 400 });

  const env = {
    GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID,
    GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET,
    GOOGLE_REDIRECT_URI: process.env.GOOGLE_REDIRECT_URI,
    TOKEN_ENCRYPTION_KEY: process.env.TOKEN_ENCRYPTION_KEY,
    DATABASE_URL: process.env.DATABASE_URL,
  };
  const missing = Object.entries(env).filter(([, v]) => !v).map(([k]) => k);
  if (missing.length) return NextResponse.json({ error: 'Missing env vars', missing }, { status: 500 });
  if (!/^[0-9a-fA-F]{64}$/.test(env.TOKEN_ENCRYPTION_KEY!)) {
    return NextResponse.json({ error: 'TOKEN_ENCRYPTION_KEY invalid' }, { status: 500 });
  }

  try {
    const { oauthClient } = await import('@/lib/gmail');
    const { prisma } = await import('@/lib/prisma');
    const { encrypt } = await import('@/lib/crypto');
    const { google } = await import('googleapis');

    const c = oauthClient();
    const { tokens } = await c.getToken(code);
    c.setCredentials(tokens);

    const oauth2 = google.oauth2({ version: 'v2', auth: c });
    const me = await oauth2.userinfo.get();
    const email = me.data.email;
    if (!email) throw new Error('Could not get email');

    // ⭐ ALWAYS use "Startup Team" as display name
    const displayName = DEFAULT_DISPLAY_NAME;

    await prisma.senderAccount.upsert({
      where: { email },
      create: {
        email,
        displayName,
        accessToken: tokens.access_token ? encrypt(tokens.access_token) : null,
        refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : null,
        tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : null,
        scope: tokens.scope,
        status: 'CONNECTED',
        isActive: true,
        warmupEnabled: false,
        dailyLimit: 350,
        warmupStartedAt: new Date(),
      },
      update: {
        // ⭐ Force name on update too
        displayName,
        accessToken: tokens.access_token ? encrypt(tokens.access_token) : undefined,
        refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : undefined,
        tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : undefined,
        scope: tokens.scope,
        status: 'CONNECTED',
        isActive: true,
      },
    });

    console.log('[oauth] Connected:', email, '| name:', displayName);
    return NextResponse.redirect(`${appUrl}/senders?connected=${encodeURIComponent(email)}`);
  } catch (err: any) {
    console.error('[oauth/callback]', err);
    return NextResponse.json({ error: 'OAuth failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/oauth/google/callback/route.ts
echo "   ✅ OAuth callback — new senders get 'Startup Team'"

# ==========================================
# 2. UPDATE EXISTING SENDERS
# ==========================================
echo ""
echo "👥 [2/4] Updating existing senders..."

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const p = new PrismaClient();
  const senders = await p.senderAccount.findMany();

  console.log(`   Found ${senders.length} sender(s)`);
  console.log("");

  let updated = 0;
  for (const s of senders) {
    const before = s.displayName || '(none)';
    if (before !== 'Startup Team') {
      await p.senderAccount.update({
        where: { id: s.id },
        data: { displayName: 'Startup Team' },
      });
      console.log(`   ✅ ${s.email}`);
      console.log(`      "${before}" → "Startup Team"`);
      updated++;
    } else {
      console.log(`   ℹ️  ${s.email} — already "Startup Team"`);
    }
  }

  console.log("");
  console.log(`   Updated: ${updated}/${senders.length}`);

  await p.$disconnect();
})().catch(e => {
  console.error("   ❌", e.message);
  process.exit(1);
});
NODEEOF

# ==========================================
# 3. UPDATE SENDERS API — auto default
# ==========================================
echo ""
echo "🔌 [3/4] Making senders API default to 'Startup Team'..."

mkdir -p app/api/senders

cat > app/api/senders/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const list = await prisma.senderAccount.findMany({
      orderBy: { createdAt: 'asc' },
    });

    return NextResponse.json(
      list.map(s => ({
        id: s.id,
        email: s.email,
        // ⭐ Always return "Startup Team" if no name set
        displayName: s.displayName || 'Startup Team',
        status: s.status,
        sentToday: s.sentToday,
        dailyLimit: s.dailyLimit || 350,
        errors: s.errors,
        reputationScore: s.reputationScore ?? 100,
        lastSuccessAt: s.lastSuccessAt,
        authorized: s.status === 'CONNECTED' && !!s.refreshToken,
        isActive: s.isActive,
      }))
    );
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/senders/route.ts
echo "   ✅ Senders API — always returns 'Startup Team'"

# ==========================================
# 4. Git push
# ==========================================
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: ALL senders default display name = 'Startup Team'"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DEFAULT SENDER NAME SET"
echo "==============================================="
echo ""
echo "🎯 What changed:"
echo "   ✓ All existing senders → 'Startup Team'"
echo "   ✓ OAuth callback → new senders get 'Startup Team' automatically"
echo "   ✓ Senders API → always returns 'Startup Team' as fallback"
echo "   ✓ Emails will show: 'Startup Team <sender@gmail.com>'"
echo ""
echo "📧 Every email now:"
echo "   From: Startup Team <yourname@gmail.com>"
echo ""
echo "⏱️  2-3 min me deploy hoga"
echo ""
echo "Test:"
echo "   1. /senders kholo → sab 'Startup Team'"
echo "   2. Naya sender connect karo → auto 'Startup Team'"
echo "   3. Test email bhejo → inbox me 'Startup Team'"
echo "==============================================="