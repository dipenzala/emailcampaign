#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔄 STRICT SENDER ROTATION (One by One)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. STRICT ROTATION LOGIC (lib)
# ==========================================
echo "📝 [1/4] Creating strict rotation logic..."

mkdir -p lib

cat > lib/sender-rotation.ts <<'EOF'
import { prisma } from './prisma';

/**
 * STRICT SEQUENTIAL ROTATION
 * --------------------------
 * Sender 1 → N emails → Sender 2 → N emails → Sender 3 → N emails
 *   → back to Sender 1 (reset batch) → ...
 *
 * Uses `rotationOrder` field for ordering.
 * Uses `batchCount` to track how many sent in current cycle.
 * Uses `lastRotationAt` (implicit via updatedAt) to determine
 * which sender goes next.
 *
 * Rules:
 *  - Only CONNECTED + isActive senders
 *  - Skip senders who hit `dailyLimit` (or warmup limit)
 *  - Move to next sender after `batchLimit` emails
 *  - After all senders hit batch, reset batchCount and start fresh
 */

const DEFAULT_BATCH = 10;

/**
 * Pick next sender using strict sequential order.
 * Returns the FIRST sender whose batchCount < batchLimit
 * AND sentToday < cap. Order by rotationOrder asc.
 */
export async function pickNextSenderStrict(opts: { batchLimit: number }) {
  const batchLimit = Math.max(1, opts.batchLimit || DEFAULT_BATCH);

  // Get all active senders ordered by rotationOrder
  const senders = await prisma.senderAccount.findMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    orderBy: [
      { rotationOrder: 'asc' },
      { createdAt: 'asc' },
    ],
  });

  if (senders.length === 0) return null;

  // Find the first sender who hasn't exceeded batch AND hasn't hit daily cap
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;       // already at cap — skip
    if (s.batchCount < batchLimit) return s; // has room in current batch
  }

  // All senders either capped OR batch full
  // If everyone batch-full, reset all batches and try again
  const resetResult = await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  if (resetResult.count === 0) return null;

  // Try again after reset — pick first available (not capped)
  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  return null; // all capped
}

/**
 * Warm-up limit calculation.
 */
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];

function effectiveCap(s: {
  warmupEnabled: boolean;
  warmupDay: number;
  dailyLimit: number;
  email?: string;
}): number {
  // Hard cap based on domain
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;

  // Warm-up cap
  let warmupCap = s.dailyLimit;
  if (s.warmupEnabled) {
    const tier = TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit);
  }

  return Math.min(providerCap, warmupCap, s.dailyLimit);
}

/**
 * Called after successful send.
 */
export async function markSenderUsed(senderId: string) {
  return prisma.senderAccount.update({
    where: { id: senderId },
    data: {
      sentToday: { increment: 1 },
      batchCount: { increment: 1 },
      lastSuccessAt: new Date(),
    },
  });
}

/**
 * Reset daily counters (run once per day).
 */
export async function resetDailyCounters() {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: startOfDay } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  return r.count;
}

/**
 * Get current rotation state (for UI display).
 */
export async function getRotationState() {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: {
      id: true, email: true, sentToday: true, dailyLimit: true,
      batchCount: true, rotationOrder: true, warmupEnabled: true,
      warmupDay: true, lastSuccessAt: true, reputationScore: true,
    },
  });

  // Determine whose turn
  let currentSender: string | null = null;
  for (const s of senders) {
    const cap = effectiveCap({ ...s, email: s.email });
    if (s.sentToday < cap && s.batchCount < 10) {
      currentSender = s.email;
      break;
    }
  }

  return { senders, currentSender };
}
EOF
sed -i 's/\r$//' lib/sender-rotation.ts
echo "   ✅ Strict sequential rotation"

# ==========================================
# 2. POLLING WORKER — use strict rotation
# ==========================================
echo ""
echo "📝 [2/4] Rewriting polling worker..."

cat > workers/polling-worker.ts <<'EOF'
import 'dotenv/config';
import { prisma } from '../lib/prisma';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '../lib/sender-rotation';
import { handleBounce } from '../lib/bounce-handler';

const POLL_INTERVAL = 3000;
const BATCH_SIZE = 5;

let running = true;
let processing = false;

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to, subject, html, text, unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  return { id: res.data.id, access, refresh };
}

async function processOne(recipient: any) {
  const { id: recipientId, campaignId } = recipient;

  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) return false;
  if (campaign.status !== 'RUNNING') return false;

  // Suppression check
  const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { suppressedCount: { increment: 1 } },
    });
    console.log(`⏭️  SKIP ${recipient.contact.email} (suppressed)`);
    return true;
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipientId },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // ============ STRICT ROTATION ============
  const sender = await pickNextSenderStrict({
    batchLimit: campaign.batchLimit ?? 10,
  });

  if (!sender) {
    console.log('⏸️  No sender available — all at cap');
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'QUEUED' },
    });
    return false;
  }

  console.log(`📤 [Sender: ${sender.email}] batch=${sender.batchCount}/${campaign.batchLimit ?? 10} sent=${sender.sentToday}/${sender.dailyLimit}`);

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  const personalizedHtml = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  const text = htmlToText(personalizedHtml);

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(
      sender, recipient.contact.email, campaign.subject, personalizedHtml, text, unsubUrl
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

    console.log(`✅ SENT [${sender.email}] → ${recipient.contact.email}`);

    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 CAMPAIGN COMPLETED');
    }

    return true;
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);
    const isPerm = /insufficient|permission|invalid_grant|unauthorized/i.test(msg);

    if (isBounce || isPerm) {
      await prisma.suppressionList.upsert({
        where: { email: recipient.contact.email },
        create: { email: recipient.contact.email, reason: isBounce ? 'BOUNCED' : 'MANUAL_BLOCK' },
        update: {},
      }).catch(() => {});
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: {
          status: isBounce ? 'BOUNCED' : 'SUPPRESSED',
          errorCode: isBounce ? 'BOUNCED' : 'AUTO_SUPPRESSED',
          errorMessage: msg.slice(0, 200),
          failedAt: new Date(),
        },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
      if (isBounce) await handleBounce({ email: recipient.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      console.log(`⛔ ${isBounce ? 'BOUNCED' : 'SUPPRESSED'} ${recipient.contact.email}`);
      return false;
    }

    // Retryable
    if (recipient.attemptCount < 3) {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'QUEUED', errorMessage: msg.slice(0, 200) },
      });
    } else {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'FAILED', errorCode: String(code), errorMessage: msg.slice(0, 200), failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
    }
    console.log(`❌ ${recipient.contact.email}: ${msg.slice(0, 60)}`);
    return false;
  }
}

async function poll() {
  if (!running || processing) return;
  processing = true;

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued`);
      for (const r of recips) {
        if (!running) break;
        await processOne(r);
      }
    }
  } catch (e: any) {
    console.error('Poll error:', e.message);
  } finally {
    processing = false;
  }
}

// ============ START ============
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🔄 STRICT ROTATION WORKER');
console.log('═══════════════════════════════════════════');
console.log('   Poll:       ' + (POLL_INTERVAL / 1000) + 's');
console.log('   Batch size: ' + BATCH_SIZE);
console.log('   Mode:       Sender 1 → Sender 2 → Sender 3 → ...');
console.log('');
console.log('🎯 Listening for QUEUED recipients...');
console.log('');

poll();
setInterval(poll, POLL_INTERVAL);

process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down...');
  running = false;
  await prisma.$disconnect();
  process.exit(0);
});
EOF
sed -i 's/\r$//' workers/polling-worker.ts
echo "   ✅ Polling worker with strict rotation"

# ==========================================
# 3. ROTATION UI PAGE
# ==========================================
echo ""
echo "🎨 [3/4] Creating rotation UI page..."

mkdir -p app/senders/rotation

cat > app/senders/rotation/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { toast } from '@/components/Toast';

export default function RotationPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [currentSender, setCurrentSender] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/senders/rotation');
      const j = await r.json();
      setSenders(j.senders || []);
      setCurrentSender(j.currentSender || null);
    } catch {}
    setLoading(false);
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  const update = async (id: string, patch: any) => {
    setBusy(true);
    try {
      await fetch('/api/senders/rotation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, ...patch }),
      });
      await load();
      toast('✅ Saved', 'success');
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const resetCounters = async () => {
    if (!confirm('Reset daily counters for all senders?')) return;
    setBusy(true);
    try {
      await fetch('/api/senders/rotation', { method: 'PUT' });
      await load();
      toast('✅ Counters reset', 'success');
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const moveUp = async (index: number) => {
    if (index === 0) return;
    const s = senders[index];
    const prev = senders[index - 1];
    await update(s.id, { rotationOrder: prev.rotationOrder });
    await update(prev.id, { rotationOrder: s.rotationOrder });
  };

  const moveDown = async (index: number) => {
    if (index >= senders.length - 1) return;
    const s = senders[index];
    const next = senders[index + 1];
    await update(s.id, { rotationOrder: next.rotationOrder });
    await update(next.id, { rotationOrder: s.rotationOrder });
  };

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🔄 Sender Rotation</h1>
        <p className="subtitle">Ek ke baad ek — Sender 1 → Sender 2 → Sender 3 → wapas Sender 1</p>
      </div>

      {/* Current sender indicator */}
      <div className="card border-violet-500/30" style={{ background: 'rgba(139,92,246,0.05)' }}>
        <div className="text-xs text-slate-400 uppercase tracking-wider mb-2">Current Sender</div>
        <div className="text-lg font-bold text-violet-300">
          {currentSender ? `📤 ${currentSender}` : '⏸️ No sender available'}
        </div>
        <div className="text-xs text-slate-500 mt-1">
          {currentSender ? 'Abhi is bhej raha hai' : 'Sab senders cap pe hain'}
        </div>
      </div>

      {/* Info */}
      <div className="card border-blue-500/30 !p-4" style={{ background: 'rgba(59,130,246,0.05)' }}>
        <div className="text-xs text-blue-300">
          <div className="font-semibold mb-1">📋 Kaise Kaam Karta Hai</div>
          <div className="text-slate-400 leading-relaxed">
            Har sender <b>{senders[0]?.dailyLimit || 10}</b> emails bhejta hai, phir <b>next sender</b> activate hota hai.
            Agar aapka batch limit 10 hai, to:
            <br />Sender 1 → 10 emails
            <br />Sender 2 → 10 emails
            <br />Sender 3 → 10 emails
            <br />Wapas Sender 1 → ...
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-2 flex-wrap">
        <button onClick={resetCounters} disabled={busy} className="btn btn-ghost text-sm">
          🔄 Reset Counters
        </button>
        <button onClick={load} disabled={busy} className="btn btn-ghost text-sm">
          🔃 Refresh
        </button>
      </div>

      {/* Sender list */}
      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : senders.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-2">📭</div>
          <p className="text-slate-400 text-sm mb-4">Koi sender connected nahi</p>
          <Link href="/senders" className="btn btn-primary">+ Add Sender</Link>
        </div>
      ) : (
        <div className="space-y-3">
          {senders.map((s, index) => {
            const isCurrent = s.email === currentSender;
            const batchLimit = s.dailyLimit || 10;
            const batchPct = Math.min(100, (s.batchCount / batchLimit) * 100);

            return (
              <div
                key={s.id}
                className={`card !p-4 ${isCurrent ? 'border-violet-500/50 ring-2 ring-violet-500/20' : ''}`}
              >
                <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-sm flex-shrink-0 ${
                      isCurrent
                        ? 'bg-gradient-to-br from-violet-500 to-pink-500 text-white'
                        : 'bg-slate-800 text-slate-400'
                    }`}>
                      {index + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm truncate">{s.email}</div>
                      {isCurrent && (
                        <div className="text-[10px] text-violet-400 font-bold uppercase tracking-wider mt-0.5">
                          ▶️ Currently Active
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 flex-shrink-0">
                    <button
                      onClick={() => moveUp(index)}
                      disabled={index === 0 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                      title="Move up"
                    >▲</button>
                    <button
                      onClick={() => moveDown(index)}
                      disabled={index === senders.length - 1 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                      title="Move down"
                    >▼</button>
                  </div>
                </div>

                {/* Stats */}
                <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold">{s.sentToday}/{s.dailyLimit}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">BATCH</div>
                    <div className="font-semibold">{s.batchCount}/{batchLimit}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">REP</div>
                    <div className={`font-semibold ${s.reputationScore >= 80 ? 'text-emerald-400' : s.reputationScore >= 50 ? 'text-amber-400' : 'text-red-400'}`}>
                      {s.reputationScore}
                    </div>
                  </div>
                </div>

                {/* Batch progress bar */}
                <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mb-3">
                  <div
                    className={`h-full ${batchPct >= 100 ? 'bg-amber-500' : 'bg-violet-500'} transition-all`}
                    style={{ width: batchPct + '%' }}
                  />
                </div>

                {/* Active toggle + limit */}
                <div className="flex items-center gap-3 flex-wrap">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={s.isActive !== false}
                      onChange={e => update(s.id, { isActive: e.target.checked })}
                      className="w-4 h-4"
                    />
                    <span className="text-xs text-slate-400">Active</span>
                  </label>
                  <div className="flex items-center gap-2">
                    <label className="text-xs text-slate-400">Batch:</label>
                    <input
                      type="number"
                      min={1}
                      max={500}
                      value={batchLimit}
                      onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 10 })}
                      className="w-16 bg-white/5 border border-white/10 rounded-lg px-2 py-1 text-xs"
                    />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
EOF
sed -i 's/\r$//' app/senders/rotation/page.tsx
echo "   ✅ Rotation UI"

# ==========================================
# 4. Update rotation API to include currentSender
# ==========================================
echo ""
echo "🔌 [4/4] Updating rotation API..."

mkdir -p app/api/senders/rotation

cat > app/api/senders/rotation/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getRotationState, resetDailyCounters } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const { senders, currentSender } = await getRotationState();
    return NextResponse.json({ senders, currentSender });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const { id, dailyLimit, rotationOrder, isActive, warmupEnabled, batchCount } = await req.json();
    if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

    const data: any = {};
    if (typeof dailyLimit === 'number') data.dailyLimit = dailyLimit;
    if (typeof rotationOrder === 'number') data.rotationOrder = rotationOrder;
    if (typeof isActive === 'boolean') data.isActive = isActive;
    if (typeof warmupEnabled === 'boolean') data.warmupEnabled = warmupEnabled;
    if (typeof batchCount === 'number') data.batchCount = batchCount;

    const updated = await prisma.senderAccount.update({ where: { id }, data });
    return NextResponse.json({ ok: true, sender: updated });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function PUT() {
  try {
    const count = await resetDailyCounters();
    return NextResponse.json({ ok: true, reset: count });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/senders/rotation/route.ts
echo "   ✅ Rotation API with currentSender"

# ==========================================
# Git push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: strict sequential sender rotation (Sender1 → Sender2 → Sender3)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ STRICT ROTATION DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 KAISE KAAM KAREGA:"
echo ""
echo "Sender 1 → 10 emails ✅"
echo "Sender 2 → 10 emails ✅"
echo "Sender 3 → 10 emails ✅"
echo "Sender 1 → next 10  ✅"
echo "Sender 2 → next 10  ✅"
echo "..."
echo ""
echo "📱 Set करना:"
echo "   /senders/rotation → har sender ka Batch limit set karo"
echo ""
echo "🔄 Order बदलना:"
echo "   ▲ ▼ buttons se sender upar/neeche karo"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "==============================================="