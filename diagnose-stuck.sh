#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 Why Is Campaign Stuck?"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const p = new PrismaClient();

  console.log("═══════════════════════════════════════════");
  console.log(" 1️⃣ CAMPAIGN STATUS");
  console.log("═══════════════════════════════════════════\n");

  const campaigns = await p.campaign.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5,
  });

  campaigns.forEach(c => {
    console.log(`   [${c.status}] ${c.name.slice(0,40)}`);
    console.log(`      Total: ${c.totalCount} | Sent: ${c.sentCount} | Failed: ${c.failedCount}`);
    console.log(`      Started: ${c.startedAt ? new Date(c.startedAt).toLocaleString() : 'never'}`);
    console.log("");
  });

  console.log("═══════════════════════════════════════════");
  console.log(" 2️⃣ SENDER STATUS (18 connected)");
  console.log("═══════════════════════════════════════════\n");

  const senders = await p.senderAccount.findMany({
    orderBy: [{ sentToday: 'asc' }],
  });

  const connected = senders.filter(s => s.status === 'CONNECTED');
  const active = connected.filter(s => s.isActive !== false);
  const withToken = active.filter(s => s.refreshToken);
  
  console.log(`   Total senders:     ${senders.length}`);
  console.log(`   Connected:         ${connected.length}`);
  console.log(`   Active:            ${active.length}`);
  console.log(`   With refresh tok:  ${withToken.length}`);
  console.log("");

  let totalCap = 0;
  let totalUsed = 0;
  
  console.log("   Top 5 by usage:");
  senders.slice(0, 5).forEach(s => {
    const cap = s.dailyLimit || 350;
    totalCap += cap;
    totalUsed += s.sentToday;
    console.log(`      ${s.email}`);
    console.log(`        Sent: ${s.sentToday}/${cap} | Batch: ${s.batchCount} | Status: ${s.status}`);
  });

  senders.forEach(s => {
    const cap = s.dailyLimit || 350;
    totalCap += 0;
    totalUsed += 0;
  });

  console.log("");
  console.log("═══════════════════════════════════════════");
  console.log(" 3️⃣ QUEUED ANALYSIS");
  console.log("═══════════════════════════════════════════\n");

  const queuedByCampaign = await p.campaignRecipient.groupBy({
    by: ['campaignId'],
    where: { status: 'QUEUED' },
    _count: { _all: true },
  });

  for (const g of queuedByCampaign) {
    const c = await p.campaign.findUnique({ where: { id: g.campaignId } });
    console.log(`   Campaign "${c?.name?.slice(0,30)}" [${c?.status}]`);
    console.log(`      QUEUED: ${g._count._all}`);
    console.log("");
  }

  console.log("═══════════════════════════════════════════");
  console.log(" 🎯 DIAGNOSIS");
  console.log("═══════════════════════════════════════════\n");

  const runningCampaigns = campaigns.filter(c => c.status === 'RUNNING');
  const pausedCampaigns = campaigns.filter(c => c.status === 'PAUSED');

  if (runningCampaigns.length === 0 && pausedCampaigns.length > 0) {
    console.log("❌ ALL CAMPAIGNS PAUSED");
    console.log("   → FIX: resume karo");
  } else if (runningCampaigns.length === 0) {
    console.log("❌ NO RUNNING CAMPAIGNS");
    console.log("   → FIX: campaign status RUNNING nahi hai");
  } else if (withToken.length === 0) {
    console.log("❌ NO ACTIVE SENDERS WITH TOKENS");
    console.log("   → FIX: senders reconnect karo");
  } else {
    console.log("✅ Campaigns RUNNING, senders ready");
    console.log("❌ → WORKER NOT RUNNING");
    console.log("");
    console.log("   Check Northflank:");
    console.log("   https://app.northflank.com/t/dipens-team/project/emailcampaign");
  }

  console.log("");
  await p.$disconnect();
})().catch(e => {
  console.error("❌", e.message);
  process.exit(1);
});
NODEEOF