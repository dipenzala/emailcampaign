#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 Queue Check"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true

# ============================================
# ⚠️ APNI REDIS_URL DAALO (asli password ke saath)
# ============================================
export REDIS_URL="rediss://default:gQAAAAAABLZ2AAIgcDE5OGMwOGM4NDA2ODU0NGJiYTI0OTlmM2VmMzFhNmQ4YQ@selected-lion-308854.upstash.io:6379"
# ============================================

node -e '
const IORedis = require("ioredis");
const { Queue } = require("bullmq");

(async () => {
  const redis = new IORedis(process.env.REDIS_URL, { maxRetriesPerRequest: null });
  await new Promise((ok, no) => { redis.once("ready", ok); redis.once("error", no); setTimeout(() => no(new Error("timeout")), 8000); });
  console.log("✅ Redis connected\n");

  // Keys
  const keys = await redis.keys("*emailcampaign*");
  console.log("=== Keys (" + keys.length + ") ===");
  keys.forEach(k => console.log("  " + k));
  console.log("");

  // Queue counts
  const q = new Queue("email-send", { connection: redis, prefix: "emailcampaign" });
  const waiting = await q.getWaitingCount();
  const active = await q.getActiveCount();
  const completed = await q.getCompletedCount();
  const failed = await q.getFailedCount();
  const delayed = await q.getDelayedCount();

  console.log("=== Queue Counts ===");
  console.log("  waiting:   " + waiting);
  console.log("  active:    " + active);
  console.log("  completed: " + completed);
  console.log("  failed:    " + failed);
  console.log("  delayed:   " + delayed);
  console.log("");

  console.log("=== VERDICT ===");
  if (waiting > 0) {
    console.log("✅ " + waiting + " jobs waiting — worker restart karo");
  } else if (active > 0) {
    console.log("⚠️  " + active + " jobs active — worker kaam kar raha hai");
  } else if (completed > 0) {
    console.log("✅ " + completed + " jobs complete — dashboard refresh karo");
  } else {
    console.log("❌ Queue empty — naya campaign banao ya retry karo");
  }

  await q.close();
  redis.quit();
})().catch(e => {
  console.error("❌ " + e.message);
  if (e.message.includes("WRONGPASS") || e.message.includes("NOAUTH")) {
    console.error("👉 REDIS_URL me password galat hai");
  }
  process.exit(1);
});
'