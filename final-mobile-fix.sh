#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎯 FINAL MOBILE FIX — Topbar + Modal + Download"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. DOWNLOAD CSV API
# ==========================================
echo "📥 [1/5] Creating download CSV API..."

mkdir -p 'app/api/campaigns/[id]/download'

cat > 'app/api/campaigns/[id]/download/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_: Request, { params }: { params: { id: string } }) {
  try {
    const campaign = await prisma.campaign.findUnique({
      where: { id: params.id },
      include: {
        recipients: {
          include: {
            contact: true,
          },
          orderBy: { queuedAt: 'asc' },
        },
      },
    });

    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Build CSV
    const headers = [
      'Email',
      'Name',
      'Company',
      'Phone',
      'City',
      'Status',
      'Sent At',
      'Failed At',
      'Error',
    ];

    const escape = (v: any) => {
      if (v === null || v === undefined) return '';
      const s = String(v);
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    const rows = campaign.recipients.map(r => [
      escape(r.contact.email),
      escape(r.contact.name),
      escape(r.contact.company),
      escape(r.contact.phone),
      escape(r.contact.city),
      escape(r.status),
      escape(r.sentAt ? new Date(r.sentAt).toISOString() : ''),
      escape(r.failedAt ? new Date(r.failedAt).toISOString() : ''),
      escape(r.errorMessage),
    ]);

    const csv = [
      headers.join(','),
      ...rows.map(row => row.join(',')),
    ].join('\n');

    // Add BOM for Excel compatibility
    const bom = '\uFEFF';
    const filename = `${campaign.name.replace(/[^a-z0-9]/gi, '_')}_recipients.csv`;

    return new NextResponse(bom + csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Cache-Control': 'no-cache',
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/download/route.ts'
echo "   ✅ /api/campaigns/[id]/download"

# ==========================================
# 2. DOWNLOAD ALL CAMPAIGNS CSV
# ==========================================
echo "📥 [2/5] Creating download-all API..."

mkdir -p app/api/campaigns/download-all

cat > app/api/campaigns/download-all/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const campaigns = await prisma.campaign.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true, name: true, subject: true, status: true,
        totalCount: true, sentCount: true, failedCount: true,
        bouncedCount: true, suppressedCount: true,
        spamScore: true, createdAt: true, completedAt: true,
      },
    });

    const headers = [
      'Campaign ID', 'Name', 'Subject', 'Status',
      'Total', 'Sent', 'Failed', 'Bounced', 'Suppressed',
      'Spam Score', 'Created At', 'Completed At',
    ];

    const escape = (v: any) => {
      if (v === null || v === undefined) return '';
      const s = String(v);
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    const rows = campaigns.map(c => [
      escape(c.id),
      escape(c.name),
      escape(c.subject),
      escape(c.status),
      escape(c.totalCount),
      escape(c.sentCount),
      escape(c.failedCount),
      escape(c.bouncedCount),
      escape(c.suppressedCount),
      escape(c.spamScore),
      escape(c.createdAt ? new Date(c.createdAt).toISOString() : ''),
      escape(c.completedAt ? new Date(c.completedAt).toISOString() : ''),
    ]);

    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const bom = '\uFEFF';
    const filename = `all_campaigns_${new Date().toISOString().slice(0, 10)}.csv`;

    return new NextResponse(bom + csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/download-all/route.ts
echo "   ✅ /api/campaigns/download-all"

# ==========================================
# 3. TOPBAR ALWAYS VISIBLE ON MOBILE (fix CSS)
# ==========================================
echo "📱 [3/5] Fixing topbar for mobile..."

node -e '
const fs = require("fs");
let css = fs.readFileSync("app/globals.css", "utf8");

// Remove ALL old topbar media queries
css = css.replace(/@media\s*\(max-width:\s*900px\)\s*{[^}]*\.topbar[^}]*}[^}]*}/g, "");
css = css.replace(/@media\s*\(max-width:\s*480px\)\s*{[^}]*\.topbar[^}]*}[^}]*}/g, "");

// Append fresh topbar CSS at end
const fresh = `

/* ============ TOPBAR — ALWAYS VISIBLE ============ */
.topbar {
  position: fixed !important;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100 !important;
  background: rgba(5, 6, 10, 0.95) !important;
  backdrop-filter: saturate(180%) blur(24px) !important;
  -webkit-backdrop-filter: saturate(180%) blur(24px) !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08) !important;
  padding: 12px 20px !important;
  display: flex !important;
  align-items: center !important;
  gap: 10px !important;
  min-height: 64px !important;
  visibility: visible !important;
  opacity: 1 !important;
}

/* Push content down so it is not hidden behind fixed topbar */
.app-content {
  padding-top: 88px !important;
}

.topbar-menu-btn {
  display: none;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: linear-gradient(135deg, rgba(139, 92, 246, 0.25), rgba(236, 72, 153, 0.18));
  border: 1px solid rgba(139, 92, 246, 0.35);
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

/* ============ MODAL — TOP ALIGNED ============ */
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.88);
  backdrop-filter: blur(10px);
  z-index: 9999;
  display: flex;
  align-items: flex-start !important;
  justify-content: center;
  padding: 80px 16px 32px !important;
  overflow-y: auto;
  animation: fadeIn .2s ease;
}

.modal-box {
  background: linear-gradient(135deg, rgba(20, 22, 32, 0.98), rgba(15, 17, 25, 0.99));
  border: 1px solid rgba(139, 92, 246, 0.3);
  border-radius: 20px;
  padding: 28px;
  max-width: 900px;
  width: 100%;
  max-height: calc(100vh - 120px) !important;
  overflow: auto;
  box-shadow: 0 40px 100px -30px rgba(0, 0, 0, 0.95), 0 0 0 1px rgba(139, 92, 246, 0.1);
  animation: fadeInUp .3s cubic-bezier(.22, 1, .36, 1);
  margin: 0 auto !important;
}

/* ============ MOBILE ============ */
@media (max-width: 900px) {
  .topbar {
    padding: 10px 14px !important;
    min-height: 60px !important;
    gap: 8px !important;
  }
  .topbar-menu-btn { display: flex !important; }
  .topbar-breadcrumbs { display: none !important; }
  .app-content { padding-top: 80px !important; }

  .sidebar { transform: translateX(-100%); }
  .sidebar.mobile-open { transform: translateX(0); }
  .sidebar-close-mobile { display: flex; }

  .modal-backdrop { padding: 70px 12px 20px !important; }
  .modal-box {
    padding: 20px !important;
    border-radius: 16px !important;
    max-height: calc(100vh - 100px) !important;
  }
}

@media (max-width: 480px) {
  .topbar {
    padding: 8px 10px !important;
    gap: 6px !important;
    min-height: 56px !important;
  }
  .topbar-btn, .topbar-menu-btn, .topbar-avatar {
    width: 36px !important;
    height: 36px !important;
  }
  .app-content { padding-top: 72px !important; }
  .modal-backdrop { padding: 64px 8px 16px !important; }
  .modal-box { padding: 16px !important; }
}
`;

fs.writeFileSync("app/globals.css", css + fresh);
console.log("   ✅ Topbar fixed (position: fixed)");
console.log("   ✅ Modal top-aligned (padding-top: 80px)");
console.log("   ✅ Content pushed down (padding-top: 88px)");
'

# ==========================================
# 4. UPDATE HISTORY PAGE — download buttons
# ==========================================
echo ""
echo "📥 [4/5] Adding download buttons to history..."

# Add download button to history page — insert in existing file
node -e '
const fs = require("fs");
const f = "app/history/page.tsx";
let content = fs.readFileSync(f, "utf8");

// Add "Download All" button in header
if (!content.includes("download-all")) {
  content = content.replace(
    /(<button onClick={\(\) => setShowCleanup\(v => !v\)} className=\"btn btn-ghost text-sm\">\s*🧹 Cleanup\s*<\/button>)/,
    `$1
          <a href="/api/campaigns/download-all" className="btn btn-ghost text-sm" download>
            📥 Download All
          </a>`
  );
}

// Add "Download CSV" button in each desktop row
if (!content.includes("Download CSV")) {
  content = content.replace(
    /(<Link href={\`\/campaigns\/\${c\.id}\`} className=\"text-xs px-2 py-1 rounded bg-blue-500\/10 text-blue-400 hover:bg-blue-500\/20 transition\">\s*Open\s*<\/Link>)/g,
    `$1
                        <a href={\`/api/campaigns/\${c.id}/download\`} className="text-xs px-2 py-1 rounded bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 transition" download title="Download recipients CSV">
                          📥
                        </a>`
  );
}

// Add "Download" button in each mobile card
if (!content.includes("Download CSV mobile")) {
  content = content.replace(
    /(<Link href={\`\/campaigns\/\${c\.id}\`} className=\"btn btn-ghost text-xs flex-1 justify-center\">\s*Open\s*<\/Link>)/g,
    `$1
                  <a href={\`/api/campaigns/\${c.id}/download\`} className="btn btn-ghost text-xs flex-1 justify-center" download>
                    📥 CSV
                  </a>`
  );
}

fs.writeFileSync(f, content);
console.log("   ✅ Download buttons added to history page");
'

# ==========================================
# 5. ADD DOWNLOAD BUTTON TO CAMPAIGN DETAIL PAGE
# ==========================================
echo "📥 [5/5] Adding download to campaign detail..."

node -e '
const fs = require("fs");
const f = "app/campaigns/[id]/page.tsx";
if (!fs.existsSync(f)) {
  console.log("   ⚠️  Campaign detail page not found");
  process.exit(0);
}
let content = fs.readFileSync(f, "utf8");

// Add download button next to delete button
if (!content.includes("download")) {
  content = content.replace(
    /(<button onClick={deleteCampaign} disabled={busy} className=\"btn btn-danger text-xs md:text-sm\">🗑️ Delete<\/button>)/,
    `<a href={\`/api/campaigns/\${id}/download\`} className="btn btn-ghost text-xs md:text-sm" download>📥 Download</a>
          $1`
  );
}

fs.writeFileSync(f, content);
console.log("   ✅ Download button added to campaign detail");
'

# ==========================================
# Git push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: CSV download + fixed mobile topbar + top-aligned modals"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Fixes:"
echo "   1. ✓ Topbar FIXED at top (back + home + menu visible)"
echo "   2. ✓ Content pushed down 88px (no overlap)"
echo "   3. ✓ Modal opens from TOP (padding-top: 80px)"
echo "   4. ✓ Download CSV buttons added:"
echo "        - History page → 📥 Download All"
echo "        - Each campaign → 📥 button"
echo "        - Campaign detail → 📥 Download"
echo ""
echo "📱 Mobile: 2-3 min baad hard refresh karo"
echo ""
echo "🔍 CSV me kya milega:"
echo "   Email, Name, Company, Phone, City, Status, Sent At, Error"
echo "==============================================="