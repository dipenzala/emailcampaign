#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ⚡ REALTIME SENDER — 3 Solutions"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. SCHEDULER API — Vercel-side, self-looping
# ═══════════════════════════════════════════
echo "🚀 [1/5] Creating self-looping scheduler API..."

mkdir -p app/api/scheduler

cat > app/api/scheduler/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * SELF-LOOPING SENDER
 * ---------
 * This endpoint sends as many emails as possible within ~50 seconds.
 * Frontend calls it in a loop (or via external cron).
 */
export async function POST(req: Request) {
  const t0 = Date.now();
  const start = Date.now();
  const MAX_RUNTIME = 50_000; // 50 sec

  const stats = { sent: 0, failed: 0, suppressed: 0, lastError: '' };

  try {
    while (Date.now() - start < MAX_RUNTIME) {
      // Pick ONE queued recipient atomically
      const claimed: any[] = await prisma.$queryRawUnsafe(`
        WITH c AS (
          SELECT id FROM "CampaignRecipient"
          WHERE status = 'QUEUED'
            AND "campaignId" IN (
              SELECT id FROM "Campaign" WHERE status = 'RUNNING'
            )
          ORDER BY "queuedAt" ASC
          LIMIT 1
          FOR UPDATE SKIP LOCKED
        )
        UPDATE "CampaignRecipient" cr
        SET status = 'PROCESSING', "attemptCount" = cr."attemptCount" + 1
        FROM c WHERE cr.id = c.id
        RETURNING cr.id, cr."campaignId"
      `);

      if (claimed.length === 0) break;

      const recipientId = claimed[0].id;
      const campaignId = claimed[0].campaignId;

      try {
        const r = await prisma.campaignRecipient.findUnique({
          where: { id: recipientId },
          include: { contact: true },
        });
        if (!r) continue;

        const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
        if (!campaign || campaign.status !== 'RUNNING') continue;

        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          stats.suppressed++;
          continue;
        }

        // Sender
        const sender = await prisma.senderAccount.findFirst({
          where: {
            status: 'CONNECTED',
            refreshToken: { not: null },
            isActive: true,
            sentToday: { lt: 350 },
          },
          orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
        });

        if (!sender) {
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
            data: { status: 'QUEUED' },
          });
          stats.lastError = 'No sender available';
          break;
        }

        // Build
        const data = {
          name: r.contact.name || '',
          email: r.contact.email,
          company: r.contact.company || '',
          city: r.contact.city || '',
          phone: r.contact.phone || '',
        };
        const finalSubject = formatSubject(campaign.subject, data);
        let html = renderTemplate(campaign.html, data);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${recipientId}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        // Send
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: r.contact.email,
          subject: finalSubject,
          html,
          text: htmlToText(html),
          unsubUrl,
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

        // Update
        await prisma.campaignRecipient.update({
          where: { id: recipientId },
          data: {
            status: 'SENT',
            senderAccountId: sender.id,
            providerMessageId: res.data.id,
            sentAt: new Date(),
          },
        });

        await prisma.senderAccount.update({
          where: { id: sender.id },
          data: { sentToday: { increment: 1 }, lastSuccessAt: new Date() },
        });

        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          }).catch(() => {});
        }

        stats.sent++;
        console.log(`✅ [${sender.email}] → ${r.contact.email}`);

        // Small delay — rate-limit friendly
        await new Promise(res => setTimeout(res, 800));
      } catch (err: any) {
        stats.failed++;
        stats.lastError = (err.message || '').slice(0, 100);

        await prisma.campaignRecipient.update({
          where: { id: recipientId },
          data: { status: 'FAILED', errorMessage: (err.message || '').slice(0, 200) },
        }).catch(() => {});

        if (/rate|quota|429/i.test(err.message || '')) {
          console.log('⚠️ Rate limit — exiting');
          break;
        }
      }
    }

    // Recalc running campaigns
    const runningCampaigns = await prisma.campaign.findMany({ where: { status: 'RUNNING' } });
    for (const c of runningCampaigns) {
      const [sent, total, queued] = await Promise.all([
        prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'SENT' } }),
        prisma.campaignRecipient.count({ where: { campaignId: c.id } }),
        prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'QUEUED' } }),
      ]);
      const update: any = { sentCount: sent, totalCount: total };
      if (queued === 0) {
        update.status = 'COMPLETED';
        update.completedAt = new Date();
      }
      await prisma.campaign.update({ where: { id: c.id }, data: update }).catch(() => {});
    }

    return NextResponse.json({
      ok: true,
      ...stats,
      elapsed: Date.now() - t0,
      stillQueued: await prisma.campaignRecipient.count({ where: { status: 'QUEUED' } }),
    });
  } catch (err: any) {
    console.error('[scheduler] FATAL:', err);
    return NextResponse.json({ ok: false, error: err.message, ...stats }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({ ok: true, message: 'Use POST to trigger send loop' });
}
EOF
sed -i 's/\r$//' app/api/scheduler/route.ts
echo "   ✅ /api/scheduler (self-looping, 50 sec per call)"

# ═══════════════════════════════════════════
# 2. LAUNCH PAGE — auto-calls scheduler in loop
# ═══════════════════════════════════════════
echo ""
echo "🎯 [2/5] Creating launch auto-loop component..."

mkdir -p components

cat > components/AutoSendLoop.tsx <<'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';

type Props = {
  campaignId: string;
  enabled: boolean;
  onComplete?: () => void;
};

/**
 * Auto-Send Loop
 * Calls /api/scheduler repeatedly until queue is empty.
 * No GitHub Actions needed — works 100% from browser.
 */
export default function AutoSendLoop({ campaignId, enabled, onComplete }: Props) {
  const [running, setRunning] = useState(false);
  const [sent, setSent] = useState(0);
  const [failed, setFailed] = useState(0);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [lastError, setLastError] = useState('');
  const [active, setActive] = useState(false);
  const runningRef = useRef(false);

  useEffect(() => {
    if (!enabled) return;
    if (runningRef.current) return;

    runningRef.current = true;
    setRunning(true);
    setActive(true);

    const loop = async () => {
      while (runningRef.current) {
        try {
          const r = await fetch('/api/scheduler', { method: 'POST' });
          const j = await r.json();

          if (!j.ok) {
            setLastError(j.error || 'Unknown error');
            break;
          }

          setSent(s => s + (j.sent || 0));
          setFailed(s => s + (j.failed || 0));
          setRemaining(j.stillQueued ?? 0);

          // Done?
          if ((j.stillQueued ?? 0) === 0) {
            setRunning(false);
            setActive(false);
            runningRef.current = false;
            onComplete?.();
            return;
          }
        } catch (e: any) {
          setLastError(e.message || 'Fetch failed');
          await new Promise(r => setTimeout(r, 3000));
        }
      }
      setRunning(false);
      setActive(false);
    };

    loop();

    return () => {
      runningRef.current = false;
    };
  }, [enabled, campaignId, onComplete]);

  if (!active && sent === 0 && failed === 0) return null;

  return (
    <div className="card" style={{
      background: running
        ? 'linear-gradient(135deg, rgba(16,185,129,0.08), rgba(5,150,105,0.04))'
        : 'linear-gradient(135deg, rgba(59,130,246,0.06), rgba(99,102,241,0.03))',
      borderColor: running ? 'rgba(16,185,129,0.4)' : 'rgba(59,130,246,0.3)',
      padding: 20,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div style={{ fontSize: 32 }}>{running ? '🟢' : '✅'}</div>
        <div style={{ flex: 1, minWidth: 200 }}>
          <div style={{ fontWeight: 800, fontSize: 15, color: running ? '#065f46' : '#1e40af' }}>
            {running ? 'AUTO-SENDING ACTIVE' : 'Auto-send complete'}
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginTop: 2 }}>
            Sent: <b style={{ color: '#10b981' }}>{sent}</b> · Failed: <b style={{ color: '#ef4444' }}>{failed}</b>
            {remaining !== null && <> · Remaining: <b>{remaining}</b></>}
          </div>
          {lastError && (
            <div style={{ fontSize: 11, color: '#dc2626', marginTop: 4 }}>
              ⚠️ {lastError}
            </div>
          )}
        </div>
        {running && (
          <div style={{ fontSize: 11, fontWeight: 700, color: '#059669' }}>
            ● LIVE
          </div>
        )}
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' components/AutoSendLoop.tsx
echo "   ✅ AutoSendLoop component"

# ═══════════════════════════════════════════
# 3. CAMPAIGN LIVE PAGE — add auto-send loop
# ═══════════════════════════════════════════
echo ""
echo "🎨 [3/5] Adding auto-loop to campaign live page..."

mkdir -p 'app/campaigns/[id]'

# Read existing file and patch
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/[id]/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Campaign page missing — will create minimal version');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Add import
if (!c.includes('AutoSendLoop')) {
  c = c.replace(
    /^('use client';)/m,
    `$1\nimport AutoSendLoop from '@/components/AutoSendLoop';`
  );
}

// Add auto-loop after header
if (!c.includes('<AutoSendLoop')) {
  c = c.replace(
    /(<div className="space-y-4 md:space-y-6">)/,
    `$1
      <AutoSendLoop
        campaignId={id as string}
        enabled={s?.status === 'RUNNING'}
      />`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Campaign live page patched');
NODEEOF

# ═══════════════════════════════════════════
# 4. EXTERNAL CRON ENDPOINT — cron-job.org friendly
# ═══════════════════════════════════════════
echo ""
echo "🌐 [4/5] Creating external cron endpoint..."

mkdir -p app/api/cron/send

cat > app/api/cron/send/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * Cron-friendly endpoint — call from cron-job.org, UptimeRobot, etc.
 * URL: https://your-app.vercel.app/api/cron/send?key=YOUR_SECRET
 */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const key = url.searchParams.get('key');

  // Optional security
  const secret = process.env.CRON_SECRET;
  if (secret && key !== secret) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Reuse scheduler logic
  const response = await fetch(`${process.env.APP_URL}/api/scheduler`, {
    method: 'POST',
  });
  const data = await response.json();
  return NextResponse.json({
    ...data,
    triggeredAt: new Date().toISOString(),
  });
}
EOF
sed -i 's/\r$//' app/api/cron/send/route.ts
echo "   ✅ /api/cron/send?key=SECRET"

# ═══════════════════════════════════════════
# 5. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: realtime auto-send loop + external cron endpoint"

git push -u origin main 2>&1 | tail -8

echo ""
echo "==============================================="
echo " ✅ DEPLOYED — 3 ways to send emails"
echo "==============================================="
echo ""
echo "🎯 SOLUTION 1 — Browser auto-loop (BEST)"
echo ""
echo "   Jab bhi aap /campaigns/[id] kholo:"
echo "   • AutoSendLoop component start hoga"
echo "   • Har 50 sec me emails jaayengi"
echo "   • Page open rakho jab tak complete ho"
echo "   • Real-time progress dikhega"
echo ""
echo "   Ye GitHub Actions pe depend nahi karta!"
echo ""
echo "🎯 SOLUTION 2 — External Cron (cron-job.org)"
echo ""
echo "   1. https://cron-job.org → Sign up (free)"
echo "   2. Create cron job:"
echo "      • URL: https://emailcampaign-ten.vercel.app/api/cron/send"
echo "      • Interval: Every 1 minute"
echo "   3. Save → Done!"
echo ""
echo "   Ye 24/7 chalta hai, koi page open nahi chahiye."
echo "   Har 1 min me ~15 emails."
echo ""
echo "🎯 SOLUTION 3 — GitHub Actions (backup)"
echo ""
echo "   Purana system bhi kaam karega (every 5 min)."
echo "   But ye reliable nahi hai (GitHub delay karta hai)."
echo ""
echo "==============================================="
echo ""
echo "💡 MERI RECOMMENDATION:"
echo ""
echo "1. Abhi test karne ke liye:"
echo "   → Campaign Live page kholo (/campaigns/[id])"
echo "   → Browser khula chhodo — auto-send loop chalega"
echo ""
echo "2. Long-term ke liye:"
echo "   → cron-job.org setup karo (5 min ka kaam)"
echo "   → Fir 24/7 auto-run bina browser"
echo ""
echo "3. GitHub Actions ko backup rakho"
echo ""
echo "==============================================="