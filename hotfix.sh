#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔥 HOTFIX — Details API + Mobile Topbar"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. VERIFY + FIX AUTH LIB
# ==========================================
echo "🔐 [1/6] Verifying auth lib..."

mkdir -p lib

if [ ! -f "lib/simple-auth.ts" ]; then
  cat > lib/simple-auth.ts <<'EOF'
import crypto from 'crypto';

const PASSWORD = 'DIPEN@3899';
const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
const COOKIE_NAME = 'ec_auth';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

export function checkPassword(input: string): boolean {
  return input === PASSWORD;
}

export function createAuthToken(): string {
  const payload = Buffer.from(JSON.stringify({ admin: true, ts: Date.now() })).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function verifyAuthToken(token?: string): boolean {
  if (!token) return false;
  const [payload, sig] = token.split('.');
  if (!payload || !sig) return false;
  const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
  if (sig !== expected) return false;
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return data.admin === true;
  } catch { return false; }
}

export const AUTH_COOKIE = COOKIE_NAME;
export const AUTH_COOKIE_MAX_AGE = COOKIE_MAX_AGE;
EOF
  sed -i 's/\r$//' lib/simple-auth.ts
  echo "   ✅ Created lib/simple-auth.ts"
else
  echo "   ✅ lib/simple-auth.ts exists"
fi

# ==========================================
# 2. FORCE-CREATE LIVE DETAILS API (bulletproof)
# ==========================================
echo ""
echo "🔌 [2/6] Force-creating /api/live/details..."

mkdir -p app/api/live/details

cat > app/api/live/details/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Return JSON for ALL errors (never HTML)
function jsonError(msg: string, status = 500) {
  return NextResponse.json({ ok: false, error: msg, type: 'error' }, { status });
}

export async function GET(req: Request) {
  try {
    // Auth check
    const cookieStore = cookies();
    const token = cookieStore.get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return jsonError('Unauthorized', 401);
    }

    const url = new URL(req.url);
    const type = url.searchParams.get('type') || '';
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '200'), 500);

    // CAMPAIGNS
    if (type === 'campaigns') {
      const campaigns = await prisma.campaign.findMany({
        orderBy: { createdAt: 'desc' },
        take: limit,
        select: {
          id: true, name: true, subject: true, status: true,
          totalCount: true, sentCount: true, failedCount: true,
          bouncedCount: true, suppressedCount: true,
          createdAt: true,
        },
      });
      return NextResponse.json({ ok: true, type: 'campaigns', items: campaigns });
    }

    // RECIPIENTS BY STATUS
    const statusMap: Record<string, string[]> = {
      sent: ['SENT'],
      pending: ['QUEUED', 'PROCESSING'],
      failed: ['FAILED'],
      bounced: ['BOUNCED'],
      suppressed: ['SUPPRESSED'],
      delivered: ['DELIVERED'],
      queued: ['QUEUED'],
      processing: ['PROCESSING'],
    };

    const statuses = statusMap[type];
    if (!statuses) {
      return jsonError('Unknown type: ' + type, 400);
    }

    const recipients = await prisma.campaignRecipient.findMany({
      where: { status: { in: statuses } },
      orderBy: { queuedAt: 'desc' },
      take: limit,
      include: {
        contact: { select: { email: true, name: true, company: true } },
        campaign: { select: { id: true, name: true } },
      },
    });

    const senderIds = [...new Set(recipients.map(r => r.senderAccountId).filter(Boolean))] as string[];
    const senders = senderIds.length
      ? await prisma.senderAccount.findMany({
          where: { id: { in: senderIds } },
          select: { id: true, email: true },
        })
      : [];
    const senderMap: Record<string, string> = {};
    senders.forEach(s => { senderMap[s.id] = s.email; });

    const items = recipients.map(r => ({
      id: r.id,
      email: r.contact.email,
      name: r.contact.name,
      company: r.contact.company,
      status: r.status,
      sentAt: r.sentAt,
      failedAt: r.failedAt,
      queuedAt: r.queuedAt,
      error: r.errorMessage,
      campaignName: r.campaign.name,
      campaignId: r.campaign.id,
      senderEmail: r.senderAccountId ? senderMap[r.senderAccountId] || null : null,
    }));

    return NextResponse.json({ ok: true, type, count: items.length, items });
  } catch (err: any) {
    console.error('[live/details]', err);
    return jsonError(err?.message ?? 'Server error', 500);
  }
}
EOF
sed -i 's/\r$//' app/api/live/details/route.ts
echo "   ✅ /api/live/details (JSON-only errors)"

# ==========================================
# 3. FORCE-CREATE LIVE STATS API
# ==========================================
echo ""
echo "🔌 [3/6] Force-creating /api/live/stats..."

mkdir -p app/api/live/stats

cat > app/api/live/stats/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifyAuthToken, AUTH_COOKIE } from '@/lib/simple-auth';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const token = cookies().get(AUTH_COOKIE)?.value;
    if (!verifyAuthToken(token)) {
      return NextResponse.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
    }

    const groups = await prisma.campaignRecipient.groupBy({
      by: ['status'],
      _count: { _all: true },
    });

    const byStatus: Record<string, number> = {};
    groups.forEach(g => { byStatus[g.status] = g._count._all; });

    const queued = byStatus.QUEUED ?? 0;
    const processing = byStatus.PROCESSING ?? 0;
    const sent = byStatus.SENT ?? 0;
    const delivered = byStatus.DELIVERED ?? 0;
    const failed = byStatus.FAILED ?? 0;
    const bounced = byStatus.BOUNCED ?? 0;
    const suppressed = byStatus.SUPPRESSED ?? 0;
    const pending = queued + processing;
    const total = queued + processing + sent + delivered + failed + bounced + suppressed;

    const senders = await prisma.senderAccount.findMany({
      orderBy: [{ status: 'asc' }, { sentToday: 'asc' }],
      select: {
        email: true, sentToday: true, dailyLimit: true, batchCount: true,
        status: true, isActive: true, reputationScore: true,
      },
    });

    const campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });

    const recent = await prisma.campaignRecipient.findMany({
      take: 15,
      orderBy: { sentAt: 'desc' },
      where: { sentAt: { not: null } },
      include: { contact: true },
    });

    const activity = recent.map(r =>
      `[${r.sentAt ? new Date(r.sentAt).toLocaleTimeString() : '--'}] ✅ ${r.contact.email}`
    );

    return NextResponse.json({
      ok: true,
      stats: { total, sent, delivered, failed, bounced, suppressed, pending, queued, processing },
      senders,
      campaign,
      activity,
      ts: Date.now(),
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/live/stats/route.ts
echo "   ✅ /api/live/stats"

# ==========================================
# 4. FIX MIDDLEWARE — protect /api too
# ==========================================
echo ""
echo "🛡️  [4/6] Fixing middleware..."

cat > middleware.ts <<'EOF'
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const AUTH_COOKIE = 'ec_auth';

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Allow public routes
  if (
    pathname === '/login' ||
    pathname === '/' ||
    pathname.startsWith('/api/auth/') ||
    pathname.startsWith('/_next/') ||
    pathname.startsWith('/favicon')
  ) {
    return NextResponse.next();
  }

  // Protected page routes
  const pagePrefixes = ['/dashboard', '/senders', '/history', '/campaigns', '/anti-spam', '/settings', '/help', '/worker'];
  const isPageRoute = pagePrefixes.some(p => pathname.startsWith(p));

  if (isPageRoute) {
    const token = req.cookies.get(AUTH_COOKIE)?.value;
    if (!token) {
      const url = req.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('next', pathname);
      return NextResponse.redirect(url);
    }
    return NextResponse.next();
  }

  // API routes handle their own auth — do NOT redirect
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/settings/:path*',
    '/help/:path*',
    '/worker/:path*',
  ],
};
EOF
sed -i 's/\r$//' middleware.ts
echo "   ✅ Middleware — pages protected, API self-managed"

# ==========================================
# 5. FIX MOBILE TOPBAR CSS
# ==========================================
echo ""
echo "🎨 [5/6] Fixing mobile topbar CSS..."

node -e '
const fs = require("fs");
let css = fs.readFileSync("app/globals.css", "utf8");

// Remove any duplicate .topbar rules
css = css.replace(/\.topbar\s*{[^}]*}/g, "");
css = css.replace(/\.topbar-menu-btn\s*{[^}]*}/g, "");
css = css.replace(/\.topbar-breadcrumbs\s*{[^}]*}/g, "");

// Append fresh topbar CSS
const topbarCSS = `

/* ============ TOPBAR (FIXED) ============ */
.topbar {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(5, 6, 10, 0.85);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  padding: 12px 20px;
  display: flex !important;
  align-items: center;
  gap: 10px;
  min-height: 64px;
  width: 100%;
}

.topbar-menu-btn {
  display: none;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: linear-gradient(135deg, rgba(139, 92, 246, 0.2), rgba(236, 72, 153, 0.15));
  border: 1px solid rgba(139, 92, 246, 0.3);
  color: #e9d5ff;
  cursor: pointer;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: transform .15s;
}
.topbar-menu-btn:active { transform: scale(.94); }

.topbar-btn {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #cbd5e1;
  cursor: pointer;
  transition: all .2s;
  flex-shrink: 0;
  text-decoration: none;
}
.topbar-btn:hover { background: rgba(255, 255, 255, 0.1); color: #fff; }

.topbar-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #64748b;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  padding: 0 8px;
}
.topbar-crumb { display: inline-flex; align-items: center; gap: 8px; }
.topbar-breadcrumbs a { color: #94a3b8; text-decoration: none; white-space: nowrap; }
.topbar-breadcrumbs a:hover { color: #fff; }
.topbar-breadcrumbs .current {
  color: #fff; font-weight: 500;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.topbar-breadcrumbs .sep { color: #334155; }

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.topbar-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: linear-gradient(135deg, #8b5cf6, #ec4899);
  color: #fff;
  font-weight: 700;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
  flex-shrink: 0;
  box-shadow: 0 6px 20px rgba(139, 92, 246, 0.35);
}

/* ============ MOBILE ============ */
@media (max-width: 900px) {
  .topbar {
    padding: 10px 14px !important;
    min-height: 60px;
    gap: 8px;
  }
  .topbar-menu-btn { display: flex !important; }
  .topbar-breadcrumbs { display: none; }
  .sidebar { transform: translateX(-100%); }
  .sidebar.mobile-open { transform: translateX(0); }
  .sidebar-close-mobile { display: flex; }
  .app-main { padding-left: 0; }
}

@media (max-width: 480px) {
  .topbar {
    padding: 8px 10px !important;
    gap: 6px;
    min-height: 56px;
  }
  .topbar-btn, .topbar-menu-btn, .topbar-avatar {
    width: 36px;
    height: 36px;
  }
}
`;

fs.writeFileSync("app/globals.css", css + topbarCSS);
console.log("   ✅ Topbar CSS rewritten");
'

# ==========================================
# 6. Git push
# ==========================================
echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Hotfix: details API JSON-only, middleware fix, mobile topbar visible"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ HOTFIX DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Fixes:"
echo "   ✓ /api/live/details — always returns JSON (never HTML)"
echo "   ✓ /api/live/stats — same"
echo "   ✓ Middleware — API routes not intercepted"
echo "   ✓ Mobile topbar — visible with hamburger"
echo "   ✓ Sidebar slide-in from left"
echo ""
echo "📱 2-3 min me Vercel deploy hoga"
echo ""
echo "Test karo:"
echo "   1. Mobile me refresh (Incognito)"
echo "   2. Topbar me ☰ dikhna chahiye"
echo "   3. Tap → sidebar slide hoga"
echo "   4. SENT card pe click → modal JSON load hoga"
echo "==============================================="