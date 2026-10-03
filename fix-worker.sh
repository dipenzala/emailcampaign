#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 Fix: Worker dedicated Redis connection"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Rewrite worker with dedicated connection
# ==========================================
echo "📝 Rewriting workers/sender.worker.ts..."

mkdir -p workers

cat > workers/sender.worker.ts <<'EOF'
import 'dotenv/config';
import IORedis from 'ioredis';
import { Worker, Job } from 'bullmq';
import { prisma } from '../lib/prisma';
import { SEND_QUEUE, QUEUE_PREFIX } from '../lib/queue';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSender, markSenderUsed } from '../lib/sender-rotation';
import { effectiveLimit } from '../lib/warmup';
import { handleBounce } from '../lib/bounce-handler';

// ==========================================
// DEDICATED WORKER CONNECTION (BullMQ requirement)
// ==========================================
function createWorkerConnection(): IORedis {
  const url = process.env.REDIS_URL || '';
  console.log('[worker-redis] Connecting to:', url.slice(0, 50) + '...');

  const client = new IORedis(url, {
    maxRetriesPerRequest: null,      // BullMQ requirement
    enableReadyCheck: false,          // Upstash friendly
    enableOfflineQueue: true,
    connectTimeout: 15000,
    keepAlive: 10000,
    retryStrategy: (times) => {
      if (times > 20) return null;
      return Math.min(times * 300, 3000);
    },
  });

  client.on('connect', () => console.log('[worker-redis] ✅ connected'));
  client.on('ready', () => console.log('[worker-redis] ✅ ready'));
  client.on('error', (e) => console.error('[worker-redis] ❌ error:', e.message));
  client.on('close', () => console.log('[worker-redis] ⚠️  closed'));
  client.on('reconnecting', () => console.log('[worker-redis] 🔄 reconnecting...'));

  return client;
}

// ==========================================
// Send via Gmail
// ==========================================
async function sendViaGmail(
  sender: any,
  to: string,
  subject: string,
  html: string,
  text: string,
  unsubUrl?: string
) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to,
    subject,
    html,
    text,
    unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  return { id: res.data.id, access, refresh };
}

// ==========================================
// JOB PROCESSOR
// ==========================================
async function processJob(job: Job) {
  const { campaignId, recipientId } = job.data;
  console.log(`\n📥 [JOB] ${job.id} → recipient ${recipientId}`);

  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) throw new Error('Campaign missing');
  if (campaign.status === 'PAUSED') throw new Error('PAUSED');
  if (campaign.status === 'STOPPED') return { skipped: true };

  const r = await prisma.campaignRecipient.findUnique({
    where: { id: recipientId },
    include: { contact: true },
  });
  if (!r) return;
  if (r.status === 'SENT' || r.status === 'DELIVERED') return { alreadySent: true };

  await prisma.campaignRecipient.update({
    where: { id: recipientId },
    data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
  });

  const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { suppressedCount: { increment: 1 } },
    });
    return;
  }

  const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
  if (!sender) throw new Error('No authorized sender available');

  const cap = effectiveLimit({
    warmupEnabled: sender.warmupEnabled,
    warmupDay: sender.warmupDay,
    dailyLimit: sender.dailyLimit,
  });
  if (sender.sentToday >= cap) {
    console.log(`⏸️  Warm-up cap reached for ${sender.email} (${sender.sentToday}/${cap})`);
    throw new Error('Sender warm-up limit reached');
  }

  console.log(
    `📤 [ROTATION] ${sender.email} (sentToday=${sender.sentToday}, batch=${sender.batchCount}/${campaign.batchLimit}, warmupDay=${sender.warmupDay})`
  );

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
  const personalizedHtml = renderTemplate(campaign.html, {
    name: r.contact.name ?? '',
    email: r.contact.email,
    company: r.contact.company ?? '',
    city: r.contact.city ?? '',
    phone: r.contact.phone ?? '',
  });
  const text = htmlToText(personalizedHtml);

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(
      sender,
      r.contact.email,
      campaign.subject,
      personalizedHtml,
      text,
      unsubUrl
    );

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId,
        sentAt: new Date(),
        errorCode: null,
        errorMessage: null,
      },
    });

    await prisma.campaign.update({
      where: { id: campaignId },
      data: { sentCount: { increment: 1 } },
    });

    await markSenderUsed(sender.id);

    if (access && refresh) {
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
      });
    }

    console.log(`✅ [SENT] ${r.contact.email} via ${sender.email}`);

    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 [CAMPAIGN COMPLETE]');
    }

    return { ok: true, sender: sender.email };
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);
    const retryable = !isBounce && (/rate|quota|429|500|502|503|timeout|ECONN/i.test(msg) || code === 429);

    if (isBounce) {
      await handleBounce({ email: r.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } },
      });
      return { bounced: true };
    }

    if (!retryable) {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
      return { failed: true };
    }
    throw err;
  }
}

// ==========================================
// WORKER INIT
// ==========================================
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🚀 Starting BullMQ Worker');
console.log('═══════════════════════════════════════════');
console.log('   Queue:      ' + SEND_QUEUE);
console.log('   Prefix:     ' + QUEUE_PREFIX);
console.log('   Concurrency: 3');
console.log('');

const worker = new Worker(SEND_QUEUE, processJob, {
  connection: createWorkerConnection(),   // ← DEDICATED connection
  prefix: QUEUE_PREFIX,
  concurrency: 3,
  drainDelay: 5,                          // faster poll for small jobs
  stalledInterval: 30000,
  maxStalledCount: 2,
});

worker.on('ready', () => console.log('🎯 [WORKER] Ready and listening for jobs'));
worker.on('active', (job) => console.log(`🔥 [WORKER] Processing job ${job.id}`));
worker.on('completed', (job) => console.log(`✅ [WORKER] Completed ${job.id}`));
worker.on('failed', (job, err) => console.error(`❌ [WORKER] Failed ${job?.id}: ${err.message}`));
worker.on('error', (err) => console.error(`❌ [WORKER] Error:`, err.message));
worker.on('stalled', (jobId) => console.warn(`⚠️  [WORKER] Stalled ${jobId}`));

// Keep process alive
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down worker...');
  await worker.close();
  process.exit(0);
});

// Prevent exit
setInterval(() => {}, 1000);
EOF
sed -i 's/\r$//' workers/sender.worker.ts
echo "   ✅ Worker rewritten with dedicated connection"

# ==========================================
# 2. Verify queue.ts uses same prefix
# ==========================================
echo ""
echo "🔎 Verifying queue.ts..."

cat > lib/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import { redis } from './redis';

export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';

let _queue: Queue | null = null;

export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, {
    connection: redis,
    prefix: QUEUE_PREFIX,
    defaultJobOptions: {
      attempts: 4,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: 1000,
      removeOnFail: 5000,
    },
  });
  return _queue;
}

export const sendQueue = new Proxy({} as Queue, {
  get(_t, prop) {
    const q = getSendQueue();
    const v = (q as any)[prop];
    return typeof v === 'function' ? v.bind(q) : v;
  },
});
EOF
sed -i 's/\r$//' lib/queue.ts
echo "   ✅ queue.ts verified"

# ==========================================
# 3. Verify
# ==========================================
echo ""
echo "🔎 Verification:"
grep -q "SEND_QUEUE = 'email-send'" lib/queue.ts && echo "   ✅ SEND_QUEUE = email-send"
grep -q "QUEUE_PREFIX = 'emailcampaign'" lib/queue.ts && echo "   ✅ QUEUE_PREFIX = emailcampaign"
grep -q "createWorkerConnection" workers/sender.worker.ts && echo "   ✅ Dedicated worker connection"
grep -q "drainDelay: 5" workers/sender.worker.ts && echo "   ✅ Fast polling enabled"

# ==========================================
# 4. Git push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: worker dedicated Redis connection + fast polling"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DONE"
echo "==============================================="
echo ""
echo "🎯 Ab karo:"
echo ""
echo "1. Worker terminal me Ctrl+C dabao"
echo ""
echo "2. Restart karo:"
echo "   bash install-and-run.sh"
echo ""
echo "3. Dekho — ab logs aise aane chahiye:"
echo "   [worker-redis] ✅ connected"
echo "   [worker-redis] ✅ ready"
echo "   🎯 [WORKER] Ready and listening for jobs"
echo "   🔥 [WORKER] Processing job ..."
echo ""
echo "Agar jobs already queue me hain to turant process hongi"
echo "==============================================="