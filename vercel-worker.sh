#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ☁️  Vercel-Based Worker (DB se hi chalega)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Create Vercel worker endpoint
# ==========================================
echo "📝 Creating /api/worker/tick/route.ts..."

mkdir -p app/api/worker/tick

cat > app/api/worker/tick/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { pickNextSender, markSenderUsed } from '@/lib/sender-rotation';
import { effectiveLimit } from '@/lib/warmup';
import { handleBounce } from '@/lib/bounce-handler';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';
export const maxDuration = 60;

const BATCH_SIZE = 5;

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

export async function GET() {
  return tick();
}

export async function POST() {
  return tick();
}

async function tick() {
  const results = {
    processed: 0,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    errors: [] as string[],
  };

  try {
    // Fetch QUEUED recipients from RUNNING campaigns
    const recipients = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: {
        contact: true,
        campaign: true,
      },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recipients.length === 0) {
      return NextResponse.json({
        ok: true,
        ...results,
        message: 'No queued recipients',
      });
    }

    for (const r of recipients) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: contact.email } });
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

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // Pick sender
        const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
        if (!sender) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED' },
          });
          results.errors.push('No sender available');
          break;
        }

        // Warm-up check
        const cap = effectiveLimit({
          warmupEnabled: sender.warmupEnabled,
          warmupDay: sender.warmupDay,
          dailyLimit: sender.dailyLimit,
        });
        if (sender.sentToday >= cap) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED' },
          });
          results.errors.push(`Warm-up cap reached for ${sender.email} (${sender.sentToday}/${cap})`);
          break;
        }

        // Build email
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        const personalizedHtml = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });
        const text = htmlToText(personalizedHtml);

        // Send
        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender,
          contact.email,
          campaign.subject,
          personalizedHtml,
          text,
          unsubUrl
        );

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

        // Check campaign complete
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
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);

        if (isBounce) {
          await handleBounce({ email: r.contact.email, senderAccountId: null, bounceType: 'HARD' });
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' },
          });
          await prisma.campaign.update({
            where: { id: r.campaignId },
            data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } },
          });
          results.bounced++;
        } else if (r.attemptCount < 3) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED', errorMessage: msg },
          });
          results.errors.push(msg);
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() },
          });
          await prisma.campaign.update({
            where: { id: r.campaignId },
            data: { failedCount: { increment: 1 } },
          });
          results.failed++;
        }
      }
    }

    return NextResponse.json({ ok: true, ...results });
  } catch (err: any) {
    console.error('[worker/tick]', err);
    return NextResponse.json(
      { ok: false, error: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
EOF
sed -i 's/\r$//' app/api/worker/tick/route.ts
echo "   ✅ Endpoint created"

# ==========================================
# 2. Simple HTML page to auto-tick
# ==========================================
echo ""
echo "📝 Creating /worker page (auto-tick UI)..."

mkdir -p app/worker

cat > app/worker/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';

export default function WorkerPage() {
  const [logs, setLogs] = useState<string[]>([]);
  const [running, setRunning] = useState(false);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0 });
  const [tick, setTick] = useState(0);

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/tick');
      const j = await r.json();
      setTick(t => t + 1);
      setStats(prev => ({
        sent: prev.sent + (j.sent ?? 0),
        failed: prev.failed + (j.failed ?? 0),
        processed: prev.processed + (j.processed ?? 0),
      }));
      const time = new Date().toLocaleTimeString();
      setLogs(prev => [
        `[${time}] processed=${j.processed ?? 0} sent=${j.sent ?? 0} failed=${j.failed ?? 0} suppressed=${j.suppressed ?? 0} bounced=${j.bounced ?? 0}`,
        ...prev.slice(0, 30),
      ]);
      if (j.message === 'No queued recipients' && running) {
        setLogs(prev => [`[${time}] ✅ All emails sent — stopping`, ...prev]);
        setRunning(false);
      }
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev]);
    }
  };

  useEffect(() => {
    if (!running) return;
    const iv = setInterval(runOnce, 5000);
    runOnce();
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="min-h-screen bg-slate-950 text-white p-6">
      <div className="max-w-3xl mx-auto space-y-6">
        <h1 className="text-3xl font-bold">☁️ Vercel Worker</h1>
        <p className="text-slate-400">Har 5 second me 5 emails process honge.</p>

        <div className="grid grid-cols-3 gap-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-slate-500">TICKS</div>
            <div className="text-2xl font-bold">{tick}</div>
          </div>
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-emerald-400">SENT</div>
            <div className="text-2xl font-bold text-emerald-400">{stats.sent}</div>
          </div>
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-red-400">FAILED</div>
            <div className="text-2xl font-bold text-red-400">{stats.failed}</div>
          </div>
        </div>

        <div className="flex gap-3">
          <button
            onClick={() => setRunning(true)}
            disabled={running}
            className="px-6 py-3 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-xl font-medium"
          >
            {running ? '🟢 Running...' : '▶️ Start Worker'}
          </button>
          <button
            onClick={() => setRunning(false)}
            disabled={!running}
            className="px-6 py-3 bg-slate-700 hover:bg-slate-600 disabled:opacity-50 rounded-xl font-medium"
          >
            ⏸️ Pause
          </button>
          <button
            onClick={runOnce}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-500 rounded-xl font-medium"
          >
            ⏭️ Step Once
          </button>
        </div>

        <div className="bg-black border border-slate-800 rounded-xl p-4 h-96 overflow-auto font-mono text-xs">
          {logs.length === 0 ? (
            <div className="text-slate-500">Click "Start Worker" to begin...</div>
          ) : (
            logs.map((l, i) => (
              <div key={i} className="text-emerald-300 py-0.5">{l}</div>
            ))
          )}
        </div>

        <div className="text-xs text-slate-500">
          💡 Ye page open rakho — ye har 5 sec me Vercel pe tick endpoint call karega.
          Emails send hote rahenge. Band karo to ruk jayega.
        </div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/worker/page.tsx
echo "   ✅ /worker UI created"

# ==========================================
# 3. Verify
# ==========================================
echo ""
echo "🔎 Verification:"
[ -f "app/api/worker/tick/route.ts" ] && echo "   ✅ tick endpoint"
[ -f "app/worker/page.tsx" ] && echo "   ✅ /worker page"

# ==========================================
# 4. Git push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: Vercel-side worker (/worker page + /api/worker/tick)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DONE — Vercel pe worker deploy hoga"
echo "==============================================="
echo ""
echo "🎯 2-3 min baad browser kholo:"
echo ""
echo "   https://emailcampaign-ten.vercel.app/worker"
echo ""
echo "Phir:"
echo "  1. '▶️ Start Worker' click karo"
echo "  2. Logs me 'sent=X' badhta dikhega"
echo "  3. Dashboard refresh karo — SENT count badhega"
echo ""
echo "Emails jaani shuru ho jayengi!"
echo "==============================================="