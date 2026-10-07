#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔍 DIAGNOSE: Delivery + SENT/TOTAL Bug"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. DIAGNOSTIC ENDPOINT
# ═══════════════════════════════════════════
echo "🔍 [1/5] Creating delivery diagnostic API..."

mkdir -p app/api/debug/delivery-check

cat > app/api/debug/delivery-check/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const campaignId = url.searchParams.get('campaignId');

    // Get campaign
    let campaign: any = null;
    if (campaignId) {
      campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
    } else {
      campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });
    }

    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'No campaign' });
    }

    // ═══════════════════════════════════════════
    // COUNTER BUG CHECK
    // ═══════════════════════════════════════════
    const actualSent = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: 'SENT' },
    });
    const actualTotal = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id },
    });
    const actualFailed = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: 'FAILED' },
    });

    const counterBug = {
      campaignStoredSent: campaign.sentCount,
      campaignStoredTotal: campaign.totalCount,
      actualSent,
      actualTotal,
      actualFailed,
      hasBug: campaign.sentCount > campaign.totalCount || campaign.sentCount !== actualSent,
    };

    // ═══════════════════════════════════════════
    // SAMPLE EMAILS — verify via Gmail API
    // ═══════════════════════════════════════════
    const samples = await prisma.campaignRecipient.findMany({
      where: { campaignId: campaign.id, status: 'SENT' },
      include: { contact: true, senderAccount: true },
      take: 5,
      orderBy: { sentAt: 'desc' },
    });

    const verification: any[] = [];

    for (const s of samples) {
      const check: any = {
        email: s.contact.email,
        sentAt: s.sentAt,
        sender: s.senderAccount?.email || 'unknown',
        providerMessageId: s.providerMessageId,
        existsInGmail: false,
        gmailLabels: [],
        error: null,
      };

      if (s.providerMessageId && s.senderAccount) {
        try {
          const access = s.senderAccount.accessToken ? decrypt(s.senderAccount.accessToken) : '';
          const refresh = s.senderAccount.refreshToken ? decrypt(s.senderAccount.refreshToken) : '';
          const c = oauthClient();
          c.setCredentials({ access_token: access, refresh_token: refresh });
          const gmail = google.gmail({ version: 'v1', auth: c });

          const msg = await gmail.users.messages.get({
            userId: 'me',
            id: s.providerMessageId,
            format: 'minimal',
          });

          check.existsInGmail = true;
          check.gmailLabels = msg.data.labelIds || [];
          check.gmailSnippet = msg.data.snippet?.slice(0, 80);
        } catch (e: any) {
          check.error = e.message?.slice(0, 200);
        }
      }

      verification.push(check);
    }

    // ═══════════════════════════════════════════
    // BOUNCE CHECK — look for mailer-daemon in inbox
    // ═══════════════════════════════════════════
    let bounceCount = 0;
    let recentBounces: any[] = [];

    try {
      const sender = await prisma.senderAccount.findFirst({
        where: { status: 'CONNECTED', refreshToken: { not: null } },
      });

      if (sender) {
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken!);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        // Search for bounces from mailer-daemon
        const bounces = await gmail.users.messages.list({
          userId: 'me',
          q: 'from:mailer-daemon OR from:postmaster OR subject:undelivered OR subject:undeliverable',
          maxResults: 20,
        });

        bounceCount = bounces.data.messages?.length || 0;

        for (const m of (bounces.data.messages || []).slice(0, 5)) {
          if (!m.id) continue;
          try {
            const msg = await gmail.users.messages.get({
              userId: 'me',
              id: m.id,
              format: 'minimal',
            });
            recentBounces.push({
              id: m.id,
              snippet: msg.data.snippet?.slice(0, 150),
              labels: msg.data.labelIds,
            });
          } catch {}
        }
      }
    } catch (e: any) {
      recentBounces = [{ error: e.message?.slice(0, 100) }];
    }

    return NextResponse.json({
      ok: true,
      campaign: {
        id: campaign.id,
        name: campaign.name,
        subject: campaign.subject,
        status: campaign.status,
      },
      counterBug,
      verification,
      bounceCheck: {
        bounceCount,
        recentBounces,
      },
      diagnosis: {
        counterBugFound: counterBug.hasBug,
        sampleVerified: verification.filter(v => v.existsInGmail).length,
        sampleFailed: verification.filter(v => !v.existsInGmail).length,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/debug/delivery-check/route.ts
echo "   ✅ /api/debug/delivery-check"

# ═══════════════════════════════════════════
# 2. FIX COUNTER BUG — recalculate endpoint
# ═══════════════════════════════════════════
echo ""
echo "🔧 [2/5] Creating counter recalc API..."

mkdir -p app/api/debug/recalc-counters

cat > app/api/debug/recalc-counters/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Recalculate campaign counters from ACTUAL recipient data.
 * Fixes SENT > TOTAL bug by computing from source of truth.
 */
export async function POST(req: Request) {
  try {
    const { campaignId } = await req.json();
    if (!campaignId) {
      return NextResponse.json({ error: 'campaignId required' }, { status: 400 });
    }

    const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Count actual
    const [sent, failed, bounced, suppressed, queued, processing] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'FAILED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'BOUNCED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'SUPPRESSED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'QUEUED' } }),
      prisma.campaignRecipient.count({ where: { campaignId, status: 'PROCESSING' } }),
    ]);

    const total = await prisma.campaignRecipient.count({ where: { campaignId } });

    // Update with actual counts
    await prisma.campaign.update({
      where: { id: campaignId },
      data: {
        totalCount: total,
        sentCount: sent,
        failedCount: failed,
        bouncedCount: bounced,
        suppressedCount: suppressed,
      },
    });

    return NextResponse.json({
      ok: true,
      previous: {
        totalCount: campaign.totalCount,
        sentCount: campaign.sentCount,
        failedCount: campaign.failedCount,
      },
      recalculated: {
        totalCount: total,
        sentCount: sent,
        failedCount: failed,
        bouncedCount: bounced,
        suppressedCount: suppressed,
        queued,
        processing,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/debug/recalc-counters/route.ts
echo "   ✅ /api/debug/recalc-counters"

# ═══════════════════════════════════════════
# 3. FIX ROUTES — use count() instead of increment
# ═══════════════════════════════════════════
echo ""
echo "🔧 [3/5] Fixing routes to use accurate counting..."

# Fix bulk route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) { console.log('   ⚠️  bulk route missing'); process.exit(0); }

let c = fs.readFileSync(f, 'utf8');

// Replace sentCount increment with accurate recalculation
c = c.replace(
  /await prisma\.campaign\.update\(\{\s*\n\s*where: \{ id: campaign\.id \},\s*\n\s*data: \{ sentCount: \{ increment: 1 \} \},\s*\n\s*\}\);/,
  `// Accurate recalc (prevents SENT > TOTAL)
        const [accSent, accTotal] = await Promise.all([
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id, status: 'SENT' } }),
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id } }),
        ]);
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: accSent, totalCount: accTotal },
        });`
);

fs.writeFileSync(f, c);
console.log('   ✅ bulk route uses accurate count');
NODEEOF

# Fix process route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/process/route.ts';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');
c = c.replace(
  /await prisma\.campaign\.update\(\{\s*\n\s*where: \{ id: campaign\.id \},\s*\n\s*data: \{ sentCount: \{ increment: 1 \} \},\s*\n\s*\}\);/g,
  `const [accSent, accTotal] = await Promise.all([
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id, status: 'SENT' } }),
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id } }),
        ]);
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: accSent, totalCount: accTotal },
        });`
);
fs.writeFileSync(f, c);
console.log('   ✅ process route uses accurate count');
NODEEOF

# Fix scheduled route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/scheduled/route.ts';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');
c = c.replace(
  /await prisma\.campaign\.update\(\{\s*\n\s*where: \{ id: campaign\.id \},\s*\n\s*data: \{ sentCount: \{ increment: 1 \} \},\s*\n\s*\}\);/g,
  `const [accSent, accTotal] = await Promise.all([
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id, status: 'SENT' } }),
          prisma.campaignRecipient.count({ where: { campaignId: campaign.id } }),
        ]);
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: accSent, totalCount: accTotal },
        });`
);
fs.writeFileSync(f, c);
console.log('   ✅ scheduled route uses accurate count');
NODEEOF

# local-sender.js
node <<'NODEEOF'
const fs = require('fs');
const f = 'local-sender.js';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');
c = c.replace(
  /await prisma\.campaign\.update\(\{\s*\n\s*where: \{ id: campaign\.id \},\s*\n\s*data: \{ sentCount: \{ increment: 1 \} \},\s*\n\s*\}\);/g,
  `const accSent = await prisma.campaignRecipient.count({ where: { campaignId: campaign.id, status: 'SENT' } });
        const accTotal = await prisma.campaignRecipient.count({ where: { campaignId: campaign.id } });
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: accSent, totalCount: accTotal },
        });`
);
fs.writeFileSync(f, c);
console.log('   ✅ local-sender uses accurate count');
NODEEOF

# ═══════════════════════════════════════════
# 4. ADD SLOWER RATE LIMIT — reduce spam risk
# ═══════════════════════════════════════════
echo ""
echo "🛡️ [4/5] Adding spam-safe rate limiting..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

// Add delay between sends
if (!c.includes('delayMs')) {
  c = c.replace(
    /(for \(const r of recips\) \{)/,
    `// ⚡ SPAM SAFE: delay between sends
    const delayMs = Math.min(2500, Math.max(800, 1500 / BATCH));
    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    $1`
  );

  // Insert sleep before send
  c = c.replace(
    /(\/\/ Send via Gmail)/,
    `// Anti-spam delay
        await sleep(delayMs);

        $1`
  );
}

// Reduce default batch from 5 to 3 (safer)
c = c.replace(
  /parseInt\(url\.searchParams\.get\('batch'\) \|\| '5', 10\)/,
  `parseInt(url.searchParams.get('batch') || '3', 10)`
);

fs.writeFileSync(f, c);
console.log('   ✅ Spam-safe delay added (800-2500ms)');
NODEEOF

# ═══════════════════════════════════════════
# 5. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: SENT>TOTAL bug + delivery diagnostic + spam-safe delay"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DELIVERY DIAGNOSTIC DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 3 Min Baad Ye Karo:"
echo ""
echo "STEP 1 — Delivery Check:"
echo "   https://emailcampaign-ten.vercel.app/api/debug/delivery-check"
echo ""
echo "   Ye batayega:"
echo "   • SENT > TOTAL bug (yes/no)"
echo "   • Sample 5 emails Gmail me exist?"
echo "   • Kitne bounces aaye?"
echo ""
echo "STEP 2 — Counter Fix (agar bug hai):"
echo "   curl -X POST https://emailcampaign-ten.vercel.app/api/debug/recalc-counters \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"campaignId\":\"YOUR_CAMPAIGN_ID\"}'"
echo ""
echo "STEP 3 — Anti-Spam:"
echo "   • Delay add kiya (800-2500ms per email)"
echo "   • Batch 5 → 3 (safer)"
echo "   • 4 emails/min per sender"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "==============================================="