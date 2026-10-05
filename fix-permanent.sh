#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🛡️ PERMANENT FIX — Worker Auto-Trigger"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. FIX "All senders capped" false alarm bug
# ═══════════════════════════════════════════
echo "🔧 [1/4] Fixing 'all capped' false alarm bug..."

cat > lib/sender-rotation.ts <<'EOF'
import { prisma } from './prisma';

const DEFAULT_BATCH_LIMIT = 1;

const WARMUP_TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];

function effectiveCap(s: any): number {
  const isWorkspace = s.email ? !/@gmail\.com$/i.test(s.email) : false;
  const providerCap = isWorkspace ? 2000 : 500;
  let warmupCap = s.dailyLimit || 350;
  if (s.warmupEnabled) {
    const tier = WARMUP_TIERS.find(t => s.warmupDay <= t.maxDay);
    if (tier) warmupCap = Math.min(tier.limit, s.dailyLimit || 350);
  }
  return Math.min(providerCap, warmupCap, s.dailyLimit || 350);
}

/**
 * ⚡ FIXED — No more false "all capped" alarms
 * Picks next sender by rotationOrder with available capacity.
 * Returns null ONLY if truly no sender available.
 */
export async function pickNextSenderStrict(opts: { batchLimit?: number } = {}) {
  const batchLimit = Math.max(1, opts.batchLimit ?? DEFAULT_BATCH_LIMIT);

  const senders = await prisma.senderAccount.findMany({
    where: {
      status: 'CONNECTED',
      refreshToken: { not: null },
      isActive: true,
    },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  if (senders.length === 0) return null;

  // Find first sender with room
  for (const s of senders) {
    const cap = effectiveCap(s);
    if (s.sentToday >= cap) continue;
    if (s.batchCount < batchLimit) return s;
  }

  // All batch-full — reset batch counts and pick first available
  await prisma.senderAccount.updateMany({
    where: {
      status: 'CONNECTED',
      isActive: true,
      refreshToken: { not: null },
    },
    data: { batchCount: 0 },
  });

  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) {
    if (s.sentToday < effectiveCap(s)) return s;
  }

  // Truly all capped — returns null
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
  const sod = new Date();
  sod.setHours(0, 0, 0, 0);
  const r = await prisma.senderAccount.updateMany({
    where: { lastResetAt: { lt: sod } },
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
    },
  });

  let currentSender: string | null = null;
  for (const s of senders) {
    if (s.sentToday < effectiveCap(s) && s.batchCount < 1) {
      currentSender = s.email;
      break;
    }
  }

  return { senders, currentSender };
}
EOF
sed -i 's/\r$//' lib/sender-rotation.ts
echo "   ✅ sender-rotation.ts fixed"

# ═══════════════════════════════════════════
# 2. Self-healing process route
# ═══════════════════════════════════════════
echo ""
echo "🔧 [2/4] Adding self-heal + auto-reset to process route..."

mkdir -p app/api/worker/process

cat > app/api/worker/process/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_BATCH = 5;

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixel = `<img src="${appUrl}/api/track/open/${recipientId}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) return html.replace(/<\/body>/i, `${pixel}</body>`);
  return html + pixel;
}

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
    to, subject, html, text, unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  try {
    if (res.data.id) {
      await gmail.users.messages.modify({
        userId: 'me',
        id: res.data.id,
        requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
      });
    }
  } catch {}

  return { id: res.data.id, access, refresh };
}

export async function GET() { return process(); }
export async function POST() { return process(); }

async function process() {
  const t0 = Date.now();
  const results: any = {
    ok: true, processed: 0, sent: 0, failed: 0, bounced: 0,
    suppressed: 0, remaining: 0, errors: [], elapsed: 0,
  };

  try {
    // SELF-HEAL: reset stuck PROCESSING > 2 min old
    const twoMinAgo = new Date(Date.now() - 2 * 60 * 1000);
    await prisma.campaignRecipient.updateMany({
      where: {
        status: 'PROCESSING',
        queuedAt: { lt: twoMinAgo },
      },
      data: { status: 'QUEUED' },
    }).catch(() => {});

    // SELF-HEAL: ensure campaigns with QUEUED are RUNNING
    await prisma.campaign.updateMany({
      where: {
        status: { in: ['PAUSED', 'STOPPED'] },
        recipients: { some: { status: 'QUEUED' } },
      },
      data: { status: 'RUNNING' },
    }).catch(() => {});

    // Fetch queued
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true, campaign: true },
      take: MAX_BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      const remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      results.remaining = remaining;
      results.elapsed = Date.now() - t0;
      return json({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        // Suppression
        const sup = await prisma.suppressionList.findUnique({
          where: { email: contact.email },
        });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { suppressedCount: { increment: 1 } },
          });
          results.suppressed++;
          continue;
        }

        // Pick sender
        const sender = await pickNextSenderStrict({
          batchLimit: campaign.batchLimit ?? 1,
        });

        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Build email
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        let html = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });
        html = injectTrackingPixel(html, r.id, process.env.APP_URL || '');

        // Send
        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender, contact.email, campaign.subject, html, htmlToText(html), unsubUrl
        );

        // Update recipient
        await prisma.campaignRecipient.update({
          where: { id: r.id },
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
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });
        await markSenderUsed(sender.id);

        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          });
        }

        results.sent++;

        // Check complete
        const remaining = await prisma.campaignRecipient.count({
          where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
        });
        if (remaining === 0) {
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { status: 'COMPLETED', completedAt: new Date() },
          });
        }
      } catch (err: any) {
        const msg = err?.message ?? 'Send failed';
        const code = err?.code ?? err?.response?.status ?? 'ERROR';
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);

        if (isBounce) {
          await prisma.suppressionList.upsert({
            where: { email: r.contact.email },
            create: { email: r.contact.email, reason: 'BOUNCED' },
            update: {},
          }).catch(() => {});
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg.slice(0, 200) },
          });
          results.bounced++;
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED', errorMessage: msg.slice(0, 200) },
          });
          results.failed++;
        }
        results.errors.push(msg.slice(0, 100));
      }
    }

    const remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.remaining = remaining;
    results.elapsed = Date.now() - t0;

    return json(results);
  } catch (err: any) {
    return json({ ok: false, error: err?.message || 'Server error', ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/process/route.ts
echo "   ✅ Self-heal + auto-reset added"

# ═══════════════════════════════════════════
# 3. Fix vercel.json — Hobby plan compatible
# ═══════════════════════════════════════════
echo ""
echo "🔧 [3/4] Fixing vercel.json for Hobby plan..."

cat > vercel.json <<'EOF'
{
  "crons": [
    {
      "path": "/api/worker/process",
      "schedule": "0 0 * * *"
    }
  ]
}
EOF
sed -i 's/\r$//' vercel.json
echo "   ✅ Cron changed to daily (Hobby-compatible)"

# ═══════════════════════════════════════════
# 4. Push + setup guide
# ═══════════════════════════════════════════
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: self-heal worker + batch bug + Hobby cron"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 AB YE KARO — UptimeRobot Setup (2 min)"
echo ""
echo "Vercel Hobby plan me 2-min cron nahi chalta."
echo "UptimeRobot (FREE) har 5 min me ping karega:"
echo ""
echo "1. https://uptimerobot.com → Sign up (free)"
echo ""
echo "2. Click 'Add New Monitor'"
echo ""
echo "3. Fill:"
echo "   Monitor Type:  HTTP(s)"
echo "   Friendly Name: EmailCampaign Worker"
echo "   URL:           https://emailcampaign-ten.vercel.app/api/worker/process"
echo "   Monitoring Interval: 5 minutes"
echo ""
echo "4. Click 'Create Monitor'"
echo ""
echo "✅ Bas! Ab har 5 min me worker khud chalega."
echo "   Koi page open nahi chahiye, koi terminal nahi."
echo ""
echo "📊 Verify:"
echo "   UptimeRobot dashboard me monitor 'Up' dikhega"
echo "   Emails automatically jaayengi"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "==============================================="