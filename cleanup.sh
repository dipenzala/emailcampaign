#!/usr/bin/env bash

echo "==============================================="
echo " 🧹 Cleanup + Fresh Campaign"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

set -a
source .env
set +a

echo ""
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. PURGE REDIS QUEUE
# ==========================================
echo "🧹 Step 1: Purging Redis queue..."
node -e '
const IORedis = require("ioredis");
const { Queue } = require("bullmq");
(async () => {
  const r = new IORedis(process.env.REDIS_URL, { maxRetriesPerRequest: null });
  await new Promise((ok, no) => { r.once("ready", ok); r.once("error", no); setTimeout(() => no(new Error("timeout")), 5000); });
  const q = new Queue("email-send", { connection: r, prefix: "emailcampaign" });
  
  console.log("Before:");
  console.log("  waiting:  ", await q.getWaitingCount());
  console.log("  failed:   ", await q.getFailedCount());
  
  await q.obliterate({ force: true });
  console.log("  ✅ Queue obliterated");
  
  console.log("After:");
  console.log("  waiting:  ", await q.getWaitingCount());
  console.log("  failed:   ", await q.getFailedCount());
  
  await q.close();
  r.quit();
})().catch(e => console.error("❌ Redis:", e.message));
'

echo ""

# ==========================================
# 2. LIST CAMPAIGNS + FIND VALID ONE
# ==========================================
echo "📋 Step 2: Listing campaigns..."
node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  
  const campaigns = await p.campaign.findMany({
    orderBy: { createdAt: "desc" },
    take: 10,
  });
  
  console.log("Recent campaigns:");
  for (const c of campaigns) {
    const count = await p.campaignRecipient.count({
      where: { campaignId: c.id, status: "QUEUED" },
    });
    console.log("  " + c.id.slice(-12) + " | " + c.status + " | total=" + c.totalCount + " | QUEUED=" + count + " | " + c.name);
  }
  
  // Find latest RUNNING with QUEUED recipients
  const best = await p.campaign.findFirst({
    where: {
      recipients: { some: { status: "QUEUED" } },
    },
    orderBy: { createdAt: "desc" },
  });
  
  if (best) {
    const queued = await p.campaignRecipient.count({
      where: { campaignId: best.id, status: "QUEUED" },
    });
    console.log("");
    console.log("✅ Best candidate: " + best.id);
    console.log("   Status: " + best.status);
    console.log("   QUEUED: " + queued);
    
    // If not RUNNING, set to RUNNING
    if (best.status !== "RUNNING") {
      await p.campaign.update({
        where: { id: best.id },
        data: { status: "RUNNING", startedAt: new Date() },
      });
      console.log("   ✅ Set to RUNNING");
    }
  } else {
    console.log("");
    console.log("❌ No campaign with QUEUED recipients!");
    console.log("   → Naya campaign banana padega (UI se)");
  }
  
  await p.$disconnect();
})().catch(e => console.error("❌ DB:", e.message));
'

echo ""
echo "==============================================="
echo " ✅ CLEANUP DONE"
echo "==============================================="
echo ""
echo "🎯 Ab kya karo:"
echo ""
echo "OPTION A: Existing campaign use karo"
echo "  1. Upar list me se ek campaign ID copy karo"
echo "  2. /worker page kholo → Start Worker"
echo ""
echo "OPTION B: Naya campaign banao (recommended)"
echo "  1. https://emailcampaign-ten.vercel.app/dashboard"
echo "  2. '+ New Campaign' click karo"
echo "  3. 5-10 test emails upload karo"
echo "  4. HTML paste karo"
echo "  5. START CAMPAIGN"
echo "  6. /worker page kholo → Start Worker"
echo ""
echo "Phir ye URL:"
echo "  https://emailcampaign-ten.vercel.app/worker"
echo "  → Start Worker"
echo "==============================================="