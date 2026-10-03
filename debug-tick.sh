#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 Debug: Emails kyun nahi ja rahi"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

set -a
source .env
set +a

# Get campaign ID
echo ""
echo "📋 Campaign ID: cmus8q2g1000ey8yazfsqm6i"
echo ""

# 1. Check queue status
echo "=== 📊 Queue Status ==="
node -e '
const IORedis = require("ioredis");
const { Queue } = require("bullmq");
(async () => {
  const r = new IORedis(process.env.REDIS_URL, { maxRetriesPerRequest: null });
  await new Promise((ok, no) => { r.once("ready", ok); r.once("error", no); setTimeout(() => no(new Error("timeout")), 5000); });
  const q = new Queue("email-send", { connection: r, prefix: "emailcampaign" });
  console.log("waiting:  ", await q.getWaitingCount());
  console.log("active:   ", await q.getActiveCount());
  console.log("completed:", await q.getCompletedCount());
  console.log("failed:   ", await q.getFailedCount());
  await q.close();
  r.quit();
})().catch(e => console.error("Redis:", e.message));
'

# 2. Check DB status
echo ""
echo "=== 📊 DB Status ==="
node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  
  // Campaign
  const c = await p.campaign.findUnique({ where: { id: "cmus8q2g1000ey8yazfsqm6i" } });
  if (c) {
    console.log("Campaign status:", c.status);
    console.log("  total:", c.totalCount);
    console.log("  sent:", c.sentCount);
    console.log("  failed:", c.failedCount);
    console.log("  batchLimit:", c.batchLimit);
  }
  
  // Recipients by status
  console.log("");
  console.log("Recipients by status:");
  const groups = await p.campaignRecipient.groupBy({
    by: ["status"],
    where: { campaignId: "cmus8q2g1000ey8yazfsqm6i" },
    _count: { _all: true },
  });
  groups.forEach(g => console.log("  " + g.status + ": " + g._count._all));
  
  // Sample 2 recipients
  console.log("");
  console.log("Sample recipients:");
  const recips = await p.campaignRecipient.findMany({
    where: { campaignId: "cmus8q2g1000ey8yazfsqm6i" },
    take: 3,
    include: { contact: true },
  });
  recips.forEach(r => {
    console.log("  " + r.contact.email + " | " + r.status + " | attempts=" + r.attemptCount + " | err=" + (r.errorMessage || "-"));
  });
  
  // Sender stats
  console.log("");
  console.log("Senders:");
  const senders = await p.senderAccount.findMany();
  senders.forEach(s => {
    console.log("  " + s.email);
    console.log("    status=" + s.status + " active=" + s.isActive);
    console.log("    sentToday=" + s.sentToday + "/" + s.dailyLimit);
    console.log("    warmupEnabled=" + s.warmupEnabled + " day=" + s.warmupDay);
    console.log("    batchCount=" + s.batchCount);
    console.log("    refreshToken=" + (s.refreshToken ? "YES" : "NO"));
  });
  
  await p.$disconnect();
})().catch(e => console.error("DB:", e.message));
'