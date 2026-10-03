#!/usr/bin/env bash

echo "==============================================="
echo " 🔍 Queue Diagnostic Check"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
echo "📁 $(pwd)"
echo ""

# ============================================
# ⚠️ EDIT KARO — APNI ACTUAL VALUES DAALO
# ============================================
export DATABASE_URL="postgresql://neondb_owner:npg_FutkNwgj2Sr5@ep-mute-queen-b5p7c2fr-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
export REDIS_URL="rediss://default:gQAAAAAABLZ2AAIgcDE5OGMwOGM4NDA2ODU0NGJiYTI0OTlmM2VmMzFhNmQ4YQ@selected-lion-308854.upstash.io:6379"
# ⬆️ Upar wali REDIS_URL me apna ASLI password daalo (Upstash console se copy karo)
# ============================================

echo "🔗 REDIS_URL: $(echo $REDIS_URL | cut -c1-60)..."
echo ""

# ============================================
# JS DEBUG RUNNER
# ============================================
node -e '
const IORedis = require("ioredis");
const { Queue } = require("bullmq");

(async () => {
  const url = process.env.REDIS_URL;
  if (!url) {
    console.error("❌ REDIS_URL not set");
    process.exit(1);
  }

  console.log("⏳ Connecting to Redis...");
  const redis = new IORedis(url, {
    maxRetriesPerRequest: null,
    connectTimeout: 8000,
    retryStrategy: (t) => t > 3 ? null : t * 500,
  });

  await new Promise((resolve, reject) => {
    redis.once("ready", resolve);
    redis.once("error", reject);
    setTimeout(() => reject(new Error("Redis timeout after 8s")), 8000);
  });
  console.log("✅ Redis connected");
  console.log("");

  // ============================================
  // 1. List all emailcampaign keys
  // ============================================
  console.log("=== 🔑 Redis Keys (emailcampaign*) ===");
  const keys = await redis.keys("*emailcampaign*");
  console.log("Total keys:", keys.length);
  if (keys.length === 0) {
    console.log("  ⚠️  No keys found!");
    console.log("     → Jobs Redis me nahi gayi hain");
  } else {
    keys.slice(0, 20).forEach(k => console.log("  •", k));
    if (keys.length > 20) console.log("  ... and", keys.length - 20, "more");
  }
  console.log("");

  // ============================================
  // 2. Queue counts
  // ============================================
  const q = new Queue("email-send", {
    connection: redis,
    prefix: "emailcampaign",
  });

  console.log("=== 📊 Queue: email-send (prefix=emailcampaign) ===");
  const waiting = await q.getWaitingCount();
  const active = await q.getActiveCount();
  const completed = await q.getCompletedCount();
  const failed = await q.getFailedCount();
  const delayed = await q.getDelayedCount();
  const paused = await q.getPausedCount();

  console.log("  waiting:   ", waiting);
  console.log("  active:    ", active);
  console.log("  completed: ", completed);
  console.log("  failed:    ", failed);
  console.log("  delayed:   ", delayed);
  console.log("  paused:    ", paused);
  console.log("");

  // ============================================
  // 3. Sample jobs
  // ============================================
  if (waiting + active + failed + completed > 0) {
    console.log("=== 📋 Sample Jobs (first 5) ===");
    const jobs = await q.getJobs(["waiting", "active", "failed", "completed"], 0, 5);
    for (const j of jobs) {
      const state = await j.getState();
      console.log(`  • id=${j.id}`);
      console.log(`    name=${j.name} state=${state}`);
      console.log(`    data=${JSON.stringify(j.data)}`);
    }
    console.log("");
  }

  // ============================================
  // 4. VERDICT
  // ============================================
  console.log("===============================================");
  console.log(" 🎯 VERDICT");
  console.log("===============================================");

  if (waiting > 0) {
    console.log("✅ Queue me " + waiting + " jobs waiting hain");
    console.log("❌ PROBLEM: Worker inhe utha nahi raha");
    console.log("");
    console.log("👉 FIX: Worker ko restart karo");
    console.log("   Terminal me: Ctrl+C, phir bash install-and-run.sh");
  } else if (active > 0) {
    console.log("⚠️  " + active + " jobs currently active hain");
    console.log("   Worker kaam kar raha hai...");
  } else if (completed > 0 && waiting === 0) {
    console.log("✅ " + completed + " jobs already complete ho gayi!");
    console.log("   Dashboard refresh karo → SENT count dikhega");
  } else if (keys.length === 0 || waiting === 0) {
    console.log("❌ Queue EMPTY hai");
    console.log("");
    console.log("👉 FIX: Naya campaign banao ya retry-queue endpoint call karo");
    console.log("");
    console.log("   Retry karne ke liye:");
    console.log("   curl -X POST \"https://emailcampaign-ten.vercel.app/api/campaigns/CAMPAIGN_ID/retry-queue\"");
  } else {
    console.log("⚠️  Unknown state - manually check karo");
  }

  console.log("");

  await q.close();
  await redis.quit();
  console.log("✅ Diagnostic complete");
})().catch(e => {
  console.error("");
  console.error("❌ ERROR:", e.message);
  console.error("");
  if (e.message.includes("WRONGPASS") || e.message.includes("NOAUTH")) {
    console.error("👉 REDIS_URL me password galat hai");
    console.error("   Upstash console se copy karo");
  } else if (e.message.includes("ECONNREFUSED")) {
    console.error("👉 Redis server reachable nahi");
  } else if (e.message.includes("timeout")) {
    console.error("👉 Redis timeout — internet check karo");
  }
  process.exit(1);
});
'