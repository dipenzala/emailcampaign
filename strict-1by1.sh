#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔄 STRICT 1-BY-1 ROTATION"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. ROTATION LOGIC — strict sequential
# ==========================================
echo "📝 [1/5] Writing strict rotation logic..."

mkdir -p lib

cat > lib/sender-rotation.ts <<'EOF'
import { prisma } from './prisma';

/**
 * STRICT 1-BY-1 ROTATION
 * -----------------------
 * Sender 1 → 1 email → Sender 2 → 1 email → Sender 3 → 1 email
 *   → wapas Sender 1 (if batchCycle = 1)
 *
 * Uses rotationOrder for sequence.
 * Uses batchCount to know how many emails current sender has sent.
 * Uses batchLimit to know when to move to next sender.
 *
 * Default batchLimit = 1 (strict one-by-one).
 */

const DEFAULT_BATCH_LIMIT = 1;

const WARMUP_TIERS = [
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
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;

  let warmupCap = s.dailyLimit;
  if (s.warmupEnabled) {
    const tier = WARMUP_TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit);
  }

  return Math.min(providerCap, warmupCap, s.dailyLimit);
}

/**
 * Pick next sender using STRICT SEQUENTIAL order.
 * Always picks the FIRST sender (by rotationOrder) who:
 *   - is CONNECTED + active + has refreshToken
 *   - has not hit daily cap
 *   - has batchCount < batchLimit (i.e., hasn't sent enough for current cycle)
 *
 * When ALL senders hit batchLimit → reset all batches to 0 → cycle restarts.
 */
export async function pickNextSenderStrict(opts: { batchLimit?: number } = {}) {
  const batchLimit = Math.max(1, opts.batchLimit ?? DEFAULT_BATCH_LIMIT);

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

  // Find first sender with room in current batch AND under daily cap
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;       // capped — skip
    if (s.batchCount < batchLimit) return s; // has room
  }

  // All senders either batch-full OR capped.
  // If some senders are batch-full but have cap room → reset batches
  const anyWithCapRoom = senders.some(s => s.sentToday < effectiveCap(s));
  if (!anyWithCapRoom) return null; // all capped — nothing to do

  await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  // Retry after reset
  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  return null;
}

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

export async function resetDailyCounters() {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: startOfDay } },
    data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() },
  });
  return r.count;
}

export async function getRotationState() {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: {
      id: true, email: true, sentToday: true, dailyLimit: true,
      batchCount: true, rotationOrder: true, warmupEnabled: true,
      warmupDay: true, lastSuccessAt: true, reputationScore: true,
      isActive: true, status: true,
    },
  });

  // Determine whose turn (batchLimit default = 1)
  let currentSender: string | null = null;
  for (const s of senders) {
    const cap = effectiveCap({ ...s, email: s.email });
    if (s.sentToday >= cap) continue;
    if (s.batchCount < 1) { currentSender = s.email; break; }
  }

  return { senders, currentSender };
}
EOF
sed -i 's/\r$//' lib/sender-rotation.ts
echo "   ✅ Strict 1-by-1 logic"

# ==========================================
# 2. WORKER — concurrency 1, batch 1
# ==========================================
echo ""
echo "📝 [2/5] Updating polling worker (strict)..."

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
const STRICT_MODE = true;              // one-by-one
let running = true;
let processing = false;

function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixelUrl = `${appUrl}/api/track/open/${recipientId}`;
  const pixel = `<img src="${pixelUrl}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) return html.replace(/<\/body>/i, `${pixel}</body>`);
  return html + pixel;
}

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
  if (!campaign || campaign.status !== 'RUNNING') return false;

  // Suppression
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

  await prisma.campaignRecipient.update({
    where: { id: recipientId },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // ============ STRICT 1-BY-1 ROTATION ============
  const batchLimit = STRICT_MODE ? 1 : (campaign.batchLimit ?? 10);

  const sender = await pickNextSenderStrict({ batchLimit });

  if (!sender) {
    console.log('⏸️  No sender available');
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'QUEUED' },
    });
    return false;
  }

  console.log(`\n📤 [SENDER] ${sender.email}`);
  console.log(`   Batch: ${sender.batchCount + 1}/${batchLimit} | Sent today: ${sender.sentToday}/${sender.dailyLimit}`);

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  let html = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  html = injectTrackingPixel(html, recipientId, process.env.APP_URL || '');

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(
      sender, recipient.contact.email, campaign.subject, html, htmlToText(html), unsubUrl
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

    console.log(`   ✅ SENT → ${recipient.contact.email}`);

    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('\n🎉 CAMPAIGN COMPLETED');
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
      console.log(`   ⛔ ${isBounce ? 'BOUNCED' : 'SUPPRESSED'} ${recipient.contact.email}`);
      return false;
    }

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
    console.log(`   ❌ ${recipient.contact.email}: ${msg.slice(0, 60)}`);
    return false;
  }
}

// ==========================================
// POLL — Strictly process ONE at a time
// ==========================================
async function poll() {
  if (!running || processing) return;
  processing = true;

  try {
    // STRICT MODE: take only 1 recipient at a time
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: 1,                    // ← ONE AT A TIME
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length > 0) {
      await processOne(recips[0]);
    }
  } catch (e: any) {
    console.error('Poll error:', e.message);
  } finally {
    processing = false;
  }
}

// ==========================================
// START
// ==========================================
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🔄 STRICT 1-BY-1 WORKER');
console.log('═══════════════════════════════════════════');
console.log('   Mode:       One email at a time');
console.log('   Rotation:   Sender 1 → Sender 2 → Sender 3 → ...');
console.log('   Concurrency: 1');
console.log('   Poll:       ' + (POLL_INTERVAL / 1000) + 's');
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
echo "   ✅ Worker — strict 1 email per sender"

# ==========================================
# 3. Campaign creation UI — strict default
# ==========================================
echo ""
echo "📝 [3/5] Updating campaign creation (strict default)..."

if [ -f "app/campaigns/new/page.tsx" ]; then
  node -e '
  const fs = require("fs");
  const f = "app/campaigns/new/page.tsx";
  let c = fs.readFileSync(f, "utf8");

  // Change default batchLimit from 10 to 1
  c = c.replace(
    /const \[batchLimit, setBatchLimit\] = useState\(10\)/,
    "const [batchLimit, setBatchLimit] = useState(1)"
  );

  fs.writeFileSync(f, c);
  console.log("   ✅ batchLimit default = 1");
  '
fi

# ==========================================
# 4. Rotation UI — clear labels
# ==========================================
echo ""
echo "📝 [4/5] Updating rotation UI..."

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
    const iv = setInterval(load, 3000);
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

  const resetAll = async () => {
    if (!confirm('Reset counters for all senders?')) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/rotation', { method: 'PUT' });
      const j = await r.json();
      toast(`✅ Reset ${j.reset} senders`, 'success');
      await load();
    } catch { toast('Failed', 'error'); }
    setBusy(false);
  };

  const moveUp = async (i: number) => {
    if (i === 0) return;
    const s = senders[i], prev = senders[i - 1];
    await update(s.id, { rotationOrder: prev.rotationOrder });
    await update(prev.id, { rotationOrder: s.rotationOrder });
  };

  const moveDown = async (i: number) => {
    if (i >= senders.length - 1) return;
    const s = senders[i], next = senders[i + 1];
    await update(s.id, { rotationOrder: next.rotationOrder });
    await update(next.id, { rotationOrder: s.rotationOrder });
  };

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">🔄 Sender Rotation</h1>
        <p className="text-sm text-slate-400 mt-1">
          Strictly one-by-one · Sender 1 → Sender 2 → Sender 3 → wapas Sender 1
        </p>
      </div>

      {/* Current sender */}
      <div className="card border-violet-500/40" style={{ background: 'rgba(139,92,246,0.06)' }}>
        <div className="text-[10px] text-slate-500 uppercase tracking-widest mb-2 font-semibold">Current Turn</div>
        <div className="flex items-center gap-3">
          <div className="text-3xl">📤</div>
          <div className="min-w-0 flex-1">
            <div className="text-lg font-bold text-violet-300 truncate">
              {currentSender || 'No sender available'}
            </div>
            <div className="text-xs text-slate-500">
              {currentSender ? 'Abhi is ki baari hai' : 'Sab senders cap pe hain'}
            </div>
          </div>
        </div>
      </div>

      {/* Info banner */}
      <div className="card border-blue-500/30 !p-4" style={{ background: 'rgba(59,130,246,0.06)' }}>
        <div className="text-xs text-blue-300 leading-relaxed">
          <div className="font-bold mb-2">📋 Rotation Order</div>
          <div className="font-mono text-[11px] text-slate-400">
            {senders.map((s, i) => (
              <div key={s.id}>#{i + 1} {s.email}</div>
            ))}
          </div>
          <div className="mt-3 text-slate-500">
            Har email ke baad agla sender aayega. Ek baar me sirf ek sender active rahega.
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-2 flex-wrap">
        <button onClick={load} disabled={busy} className="btn btn-ghost text-sm">🔃 Refresh</button>
        <button onClick={resetAll} disabled={busy} className="btn btn-ghost text-sm">🔄 Reset Counters</button>
        <Link href="/senders" className="btn btn-ghost text-sm">+ Add Sender</Link>
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
          {senders.map((s, i) => {
            const isCurrent = s.email === currentSender;
            const cap = s.dailyLimit || 500;
            const pct = Math.min(100, (s.sentToday / cap) * 100);

            return (
              <div
                key={s.id}
                className={`card !p-4 ${isCurrent ? 'border-violet-500/60 ring-2 ring-violet-500/25' : ''}`}
              >
                <div className="flex items-start justify-between gap-3 mb-3 flex-wrap">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className={`w-11 h-11 rounded-xl flex items-center justify-center font-bold text-base flex-shrink-0 ${
                      isCurrent
                        ? 'bg-gradient-to-br from-violet-500 to-pink-500 text-white shadow-lg shadow-violet-500/40'
                        : 'bg-slate-800 text-slate-400'
                    }`}>
                      {isCurrent ? '▶' : i + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm truncate">{s.email}</div>
                      {isCurrent && (
                        <div className="text-[10px] text-violet-400 font-bold uppercase tracking-widest mt-0.5">
                          ● Active Now
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 flex-shrink-0">
                    <button
                      onClick={() => moveUp(i)}
                      disabled={i === 0 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                    >▲</button>
                    <button
                      onClick={() => moveDown(i)}
                      disabled={i === senders.length - 1 || busy}
                      className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 text-slate-400 hover:text-white disabled:opacity-30 text-xs"
                    >▼</button>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">SENT TODAY</div>
                    <div className="font-semibold">{s.sentToday}/{cap}</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">BATCH</div>
                    <div className="font-semibold">{s.batchCount}/1</div>
                  </div>
                  <div className="bg-white/5 rounded-lg p-2">
                    <div className="text-slate-500 text-[10px]">REP</div>
                    <div className={`font-semibold ${
                      s.reputationScore >= 80 ? 'text-emerald-400'
                      : s.reputationScore >= 50 ? 'text-amber-400'
                      : 'text-red-400'
                    }`}>{s.reputationScore}</div>
                  </div>
                </div>

                <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden mb-3">
                  <div
                    className={`h-full ${pct >= 100 ? 'bg-red-500' : pct >= 70 ? 'bg-amber-500' : 'bg-emerald-500'}`}
                    style={{ width: pct + '%' }}
                  />
                </div>

                <div className="flex items-center justify-between flex-wrap gap-3">
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
                    <label className="text-xs text-slate-400">Daily Limit:</label>
                    <input
                      type="number"
                      min={1}
                      max={500}
                      value={s.dailyLimit}
                      onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 500 })}
                      className="w-20 bg-white/5 border border-white/10 rounded-lg px-2 py-1 text-xs"
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
echo "   ✅ Rotation UI updated"

# ==========================================
# 5. Git push
# ==========================================
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: strict 1-by-1 sender rotation (one email per sender)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ STRICT 1-BY-1 ROTATION DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 NAYA BEHAVIOR:"
echo ""
echo "   Email 1  →  Sender 1"
echo "   Email 2  →  Sender 2"
echo "   Email 3  →  Sender 3"
echo "   Email 4  →  Sender 1  (wapas)"
echo "   Email 5  →  Sender 2"
echo "   Email 6  →  Sender 3"
echo "   ..."
echo ""
echo "⏱️  Ek time pe sirf ek sender bhejta hai"
echo "📊 Worker concurrency: 1"
echo "📬 Batch size: 1 email per sender"
echo ""
echo "Restart karo worker:"
echo "   • Northflank → Redeploy"
echo "   • Ya local: bash run.sh"
echo "==============================================="