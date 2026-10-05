#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 WHERE IS IT STUCK?"
echo "==============================================="
echo ""

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# Load env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
  echo "✅ .env loaded"
else
  echo "❌ .env nahi mila"
  exit 1
fi
echo ""

# ═══════════════════════════════════════════
# PART 1: DATABASE — Campaigns, Senders, Queue
# ═══════════════════════════════════════════
echo "═══════════════════════════════════════════"
echo " 📊 PART 1: DATABASE STATE"
echo "═══════════════════════════════════════════"
echo ""

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const p = new PrismaClient();

  // ── 1. All Campaigns
  console.log("📍 LATEST 5 CAMPAIGNS:");
  const campaigns = await p.campaign.findMany({
    orderBy: { createdAt: "desc" },
    take: 5,
  });

  if (campaigns.length === 0) {
    console.log("   ❌ No campaigns found\n");
  } else {
    for (const c of campaigns) {
      const queued = await p.campaignRecipient.count({
        where: { campaignId: c.id, status: "QUEUED" },
      });
      const sent = await p.campaignRecipient.count({
        where: { campaignId: c.id, status: "SENT" },
      });
      console.log(`   [${c.status}] ${c.name.slice(0, 40)}`);
      console.log(`      Total: ${c.totalCount} | Sent: ${sent} | Queued: ${queued}`);
      console.log(`      Created: ${new Date(c.createdAt).toLocaleString()}`);
    }
    console.log("");
  }

  // ── 2. Senders
  console.log("📍 SENDERS STATUS:");
  const senders = await p.senderAccount.findMany({
    orderBy: { sentToday: "desc" },
  });

  const totalSenders = senders.length;
  const connected = senders.filter(s => s.status === "CONNECTED").length;
  const active = senders.filter(s => s.isActive !== false).length;
  const withToken = senders.filter(s => s.refreshToken).length;
  const notCapped = senders.filter(s => {
    const cap = s.dailyLimit || 350;
    return s.sentToday < cap && s.status === "CONNECTED" && s.refreshToken;
  }).length;

  console.log(`   Total senders:      ${totalSenders}`);
  console.log(`   Connected:          ${connected}`);
  console.log(`   Active:             ${active}`);
  console.log(`   With token:         ${withToken}`);
  console.log(`   Available (not capped): ${notCapped}`);
  console.log("");

  if (senders.length > 0) {
    console.log("   First 5 senders:");
    for (const s of senders.slice(0, 5)) {
      const cap = s.dailyLimit || 350;
      console.log(`      ${s.email}`);
      console.log(`        ${s.status} | Active:${s.isActive} | ${s.sentToday}/${cap} | Token:${s.refreshToken ? "YES" : "NO"}`);
    }
    console.log("");
  }

  // ── 3. Queue breakdown
  console.log("📍 ALL RECIPIENTS (by status):");
  const groups = await p.campaignRecipient.groupBy({
    by: ["status"],
    _count: { _all: true },
  });

  if (groups.length === 0) {
    console.log("   ❌ No recipients in DB at all\n");
  } else {
    const order = ["QUEUED", "PROCESSING", "SENT", "DELIVERED", "FAILED", "BOUNCED", "SUPPRESSED"];
    for (const status of order) {
      const g = groups.find(x => x.status === status);
      if (g) {
        console.log(`   ${status.padEnd(12)} → ${g._count._all}`);
      }
    }
    console.log("");
  }

  // ── 4. Recent activity (last 10 minutes)
  console.log("📍 RECENT ACTIVITY (last 10 min):");
  const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000);
  const recentSent = await p.campaignRecipient.count({
    where: { status: "SENT", sentAt: { gte: tenMinAgo } },
  });
  console.log(`   Emails sent in last 10 min: ${recentSent}`);

  const lastSent = await p.campaignRecipient.findFirst({
    where: { status: "SENT" },
    orderBy: { sentAt: "desc" },
    include: { contact: true },
  });

  if (lastSent) {
    console.log(`   Last email sent: ${new Date(lastSent.sentAt).toLocaleString()}`);
    console.log(`   To: ${lastSent.contact.email}`);
    const minutesAgo = Math.floor((Date.now() - new Date(lastSent.sentAt).getTime()) / 60000);
    console.log(`   ${minutesAgo} minutes ago`);
  } else {
    console.log("   ❌ No emails ever sent");
  }
  console.log("");

  await p.$disconnect();
})().catch(e => {
  console.error("❌ DB error:", e.message);
  process.exit(1);
});
NODEEOF

# ═══════════════════════════════════════════
# PART 2: VERCEL API — Live Stats
# ═══════════════════════════════════════════
echo "═══════════════════════════════════════════"
echo " 🌐 PART 2: VERCEL API CHECK"
echo "═══════════════════════════════════════════"
echo ""

APP_URL="${APP_URL:-https://emailcampaign-ten.vercel.app}"

echo "📍 Health check:"
curl -s -m 10 "$APP_URL/api/health" | head -c 200
echo ""
echo ""

echo "📍 Queue health:"
curl -s -m 10 "$APP_URL/api/queue/health" | head -c 200
echo ""
echo ""

# ═══════════════════════════════════════════
# PART 3: CONCLUSION
# ═══════════════════════════════════════════
echo "═══════════════════════════════════════════"
echo " 🎯 VERDICT"
echo "═══════════════════════════════════════════"
echo ""

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const p = new PrismaClient();

  const queued = await p.campaignRecipient.count({ where: { status: "QUEUED" } });
  const runningCampaigns = await p.campaign.findMany({ where: { status: "RUNNING" } });

  const senders = await p.senderAccount.findMany();
  const availableSenders = senders.filter(s => {
    const cap = s.dailyLimit || 350;
    return s.status === "CONNECTED" && s.refreshToken && s.isActive !== false && s.sentToday < cap;
  });

  const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000);
  const recentActivity = await p.campaignRecipient.count({
    where: { sentAt: { gte: tenMinAgo } },
  });

  console.log("┌─────────────────────────────────────────┐");
  console.log("│  QUEUED emails:        " + String(queued).padStart(6) + "             │");
  console.log("│  RUNNING campaigns:    " + String(runningCampaigns.length).padStart(6) + "             │");
  console.log("│  Available senders:    " + String(availableSenders.length).padStart(6) + "             │");
  console.log("│  Sent (last 10 min):   " + String(recentActivity).padStart(6) + "             │");
  console.log("└─────────────────────────────────────────┘");
  console.log("");

  if (queued === 0) {
    console.log("✅ Nothing stuck. All emails processed.");
  } else if (runningCampaigns.length === 0) {
    console.log("❌ ISSUE #1: " + queued + " emails QUEUED but NO RUNNING campaign");
    console.log("");
    console.log("👉 FIX: Campaign ko RUNNING karo:");
    console.log("   https://emailcampaign-ten.vercel.app/history");
    console.log("   → Latest campaign kholo → RESUME click karo");
  } else if (availableSenders.length === 0) {
    console.log("❌ ISSUE #2: " + queued + " emails QUEUED but NO available sender");
    console.log("");
    console.log("👉 Possible reasons:");
    console.log("   1. All senders hit daily cap (350/day each)");
    console.log("   2. Senders tokens expired (reconnect karo)");
    console.log("   3. All senders inactive/disconnected");
    console.log("");
    console.log("👉 FIX:");
    console.log("   https://emailcampaign-ten.vercel.app/senders");
    console.log("   → Senders Reconnect karo / new add karo");
  } else if (recentActivity === 0) {
    console.log("❌ ISSUE #3: " + queued + " emails QUEUED, senders available");
    console.log("         BUT worker ne last 10 min me kuch nahi bheja");
    console.log("");
    console.log("👉 FIX: Northflank worker redeploy karo:");
    console.log("   https://app.northflank.com/t/dipens-team/project/emailcampaign");
    console.log("   → Service → Deployments → Redeploy");
  } else {
    console.log("✅ WORKER IS RUNNING!");
    console.log("   Last 10 min me " + recentActivity + " emails bheji hain.");
    console.log("");
    console.log("💡 Dashboard stale ho sakta hai. Hard refresh karo:");
    console.log("   Ctrl + Shift + R");
  }

  console.log("");
  await p.$disconnect();
})().catch(e => console.error("❌", e.message));
NODEEOF

echo ""
echo "═══════════════════════════════════════════"
echo " ✅ Diagnostic complete"
echo "═══════════════════════════════════════════"