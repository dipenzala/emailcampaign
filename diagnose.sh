#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 DIAGNOSTIC — Why Emails Are Stuck"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

set -a
source .env
set +a

node <<'NODEEOF'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const p = new PrismaClient();

  console.log("═══════════════════════════════════════════");
  console.log(" 1️⃣ RUNNING CAMPAIGNS");
  console.log("═══════════════════════════════════════════\n");

  const running = await p.campaign.findMany({
    where: { status: "RUNNING" },
    orderBy: { createdAt: "desc" },
    take: 10,
  });

  if (running.length === 0) {
    console.log("   ❌ No RUNNING campaigns!\n");
  } else {
    for (const c of running) {
      const queued = await p.campaignRecipient.count({
        where: { campaignId: c.id, status: "QUEUED" },
      });
      console.log(`   ✅ ${c.name.slice(0, 35)}`);
      console.log(`      ID: ${c.id}`);
      console.log(`      QUEUED recipients: ${queued}`);
      console.log(`      Started: ${c.startedAt ? new Date(c.startedAt).toLocaleString() : 'never'}`);
      console.log("");
    }
  }

  console.log("═══════════════════════════════════════════");
  console.log(" 2️⃣ SENDERS");
  console.log("═══════════════════════════════════════════\n");

  const senders = await p.senderAccount.findMany({
    orderBy: [{ status: "asc" }, { sentToday: "asc" }],
  });

  const connected = senders.filter(s => s.status === "CONNECTED");
  const active = connected.filter(s => s.isActive !== false);
  const withToken = active.filter(s => s.refreshToken);

  console.log(`   Total:              ${senders.length}`);
  console.log(`   Connected:          ${connected.length}`);
  console.log(`   Active:             ${active.length}`);
  console.log(`   With refreshToken:  ${withToken.length}`);
  console.log("");

  if (senders.length === 0) {
    console.log("   ❌ NO SENDERS CONNECTED\n");
  } else {
    console.log("   First 3 senders:");
    for (const s of senders.slice(0, 3)) {
      const cap = s.dailyLimit || 350;
      const pct = cap > 0 ? ((s.sentToday / cap) * 100).toFixed(0) : 0;
      console.log(`      ${s.email}`);
      console.log(`        Status: ${s.status} | Active: ${s.isActive} | Warmup: ${s.warmupEnabled ? 'Day ' + s.warmupDay : 'OFF'}`);
      console.log(`        Sent: ${s.sentToday}/${cap} (${pct}%) | Batch: ${s.batchCount} | Tokens: ${s.refreshToken ? 'YES' : 'NO'}`);
    }
    console.log("");
  }

  console.log("═══════════════════════════════════════════");
  console.log(" 3️⃣ QUEUED RECIPIENTS BREAKDOWN");
  console.log("═══════════════════════════════════════════\n");

  const queuedByStatus = await p.campaignRecipient.groupBy({
    by: ["status"],
    _count: { _all: true },
  });

  for (const g of queuedByStatus) {
    console.log(`   ${g.status.padEnd(12)} → ${g._count._all}`);
  }
  console.log("");

  console.log("═══════════════════════════════════════════");
  console.log(" 4️⃣ RECENT SUCCESS");
  console.log("═══════════════════════════════════════════\n");

  const recentSent = await p.campaignRecipient.findMany({
    where: { status: "SENT" },
    orderBy: { sentAt: "desc" },
    take: 5,
    include: { contact: true },
  });

  if (recentSent.length === 0) {
    console.log("   ⚠️  No emails ever sent\n");
  } else {
    console.log("   Last 5 sent emails:");
    for (const r of recentSent) {
      console.log(`      ${r.sentAt ? new Date(r.sentAt).toLocaleString() : '?'} → ${r.contact.email}`);
    }
    console.log("");
  }

  console.log("═══════════════════════════════════════════");
  console.log(" 🎯 DIAGNOSIS");
  console.log("═══════════════════════════════════════════\n");

  const queuedTotal = queuedByStatus.find(g => g.status === "QUEUED")?._count._all || 0;

  if (queuedTotal === 0) {
    console.log("   ✅ Nothing is stuck. Queue is empty.\n");
  } else if (running.length === 0) {
    console.log("   ❌ PROBLEM: " + queuedTotal + " emails QUEUED but NO running campaign");
    console.log("   → FIX: Campaign ko RUNNING karo\n");
  } else if (withToken.length === 0) {
    console.log("   ❌ PROBLEM: " + queuedTotal + " emails QUEUED but NO sender with valid token");
    console.log("   → FIX: /senders pe jaake sender reconnect karo\n");
  } else {
    // Check if all senders are capped
    const allCapped = active.every(s => {
      const cap = s.dailyLimit || 350;
      return s.sentToday >= cap;
    });

    if (allCapped) {
      console.log("   ⚠️  All senders hit daily cap");
      console.log("   → FIX: Kal tak wait karo ya counters reset karo\n");
    } else {
      console.log("   ✅ All looks good — Worker not running");
      console.log("   → FIX: Worker chalao\n");
      console.log("   Command:");
      console.log("      bash local-sender.sh");
      console.log("");
      console.log("   Ya Northflank redeploy:");
      console.log("      https://app.northflank.com/t/dipens-team/project/emailcampaign");
    }
  }

  console.log("");
  await p.$disconnect();
})().catch(e => {
  console.error("❌ Error:", e.message);
  process.exit(1);
});
NODEEOF