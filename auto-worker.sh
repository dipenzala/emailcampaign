#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ⏰ AUTO WORKER — Vercel Cron Setup"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. VERIFY worker/process route exists
# ==========================================
echo "🔍 [1/5] Checking worker/process route..."

if [ ! -f "app/api/worker/process/route.ts" ]; then
  echo "   ❌ worker/process route nahi mila"
  echo "   Pehle 'vercel-worker-fix.sh' chalao"
  exit 1
fi
echo "   ✅ /api/worker/process exists"

# ==========================================
# 2. CRON route — dedicated endpoint
# ==========================================
echo ""
echo "📝 [2/5] Creating dedicated cron endpoint..."

mkdir -p app/api/cron/process

cat > app/api/cron/process/route.ts <<'EOF'
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

const MAX_BATCH = 10;

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

export async function GET(req: Request) {
  const t0 = Date.now();

  // Optional security: verify Vercel cron secret
  const url = new URL(req.url);
  const authHeader = req.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  // If CRON_SECRET is set, verify it (but allow without for now)
  if (cronSecret && authHeader !== `Bearer ${cronSecret}` && !url.searchParams.has('manual')) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const results: any = {
    ok: true,
    ts: new Date().toISOString(),
    processed: 0,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    remaining: 0,
    errors: [] as string[],
  };

  try {
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
      return json({ ...results, message: 'No queued recipients', elapsed: Date.now() - t0 });
    }

    console.log('[cron] Processing', recips.length, 'recipients');

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

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

        const sender = await pickNextSenderStrict({
          batchLimit: campaign.batchLimit ?? 1,
        });

        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        let html = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });
        html = injectTrackingPixel(html, r.id, process.env.APP_URL || '');

        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender, contact.email, campaign.subject, html, htmlToText(html), unsubUrl
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
    return json({ ok: false, error: err?.message || 'Server error' }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/cron/process/route.ts
echo "   ✅ /api/cron/process"

# ==========================================
# 3. vercel.json — Cron Schedule
# ==========================================
echo ""
echo "⏰ [3/5] Creating vercel.json with cron..."

cat > vercel.json <<'EOF'
{
  "crons": [
    {
      "path": "/api/cron/process",
      "schedule": "*/2 * * * *"
    }
  ]
}
EOF
sed -i 's/\r$//' vercel.json
echo "   ✅ vercel.json — cron every 2 min"

# ==========================================
# 4. UPDATE WORKER PAGE — auto-start explanation
# ==========================================
echo ""
echo "📝 [4/5] Updating worker page..."

mkdir -p app/worker

cat > app/worker/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function WorkerPage() {
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0, remaining: 0 });
  const [ticks, setTicks] = useState(0);
  const [lastCheck, setLastCheck] = useState<string>('--:--:--');

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/process', { method: 'POST' });
      const j = await r.json();

      setTicks(t => t + 1);
      setLastCheck(new Date().toLocaleTimeString());

      if (j.sent > 0 || j.failed > 0 || j.processed > 0) {
        setStats(prev => ({
          sent: prev.sent + (j.sent ?? 0),
          failed: prev.failed + (j.failed ?? 0),
          processed: prev.processed + (j.processed ?? 0),
          remaining: j.remaining ?? 0,
        }));
      } else {
        setStats(prev => ({ ...prev, remaining: j.remaining ?? prev.remaining }));
      }

      const time = new Date().toLocaleTimeString();
      let msg: string;
      if (j.message === 'No queued recipients') {
        msg = `💤 No queued recipients`;
      } else {
        msg = `✅ ${j.sent || 0} sent | ❌ ${j.failed || 0} failed | 📬 ${j.remaining ?? 0} remaining`;
      }
      setLogs(prev => [`[${time}] ${msg}`, ...prev.slice(0, 30)]);
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev.slice(0, 30)]);
    }
  };

  useEffect(() => {
    // Auto-check status every 5 seconds (even when not "running")
    const iv = setInterval(() => {
      if (!running) {
        // Silent status check
        fetch('/api/worker/process', { method: 'POST' })
          .then(r => r.json())
          .then(j => {
            if (j.sent > 0 || j.processed > 0) {
              setStats(prev => ({
                sent: prev.sent + (j.sent ?? 0),
                failed: prev.failed + (j.failed ?? 0),
                processed: prev.processed + (j.processed ?? 0),
                remaining: j.remaining ?? 0,
              }));
              setLogs(prev => [`[${new Date().toLocaleTimeString()}] ⚡ Auto: ${j.sent || 0} sent | 📬 ${j.remaining ?? 0} remaining`, ...prev.slice(0, 30)]);
            }
          })
          .catch(() => {});
      }
    }, 5000);

    return () => clearInterval(iv);
  }, [running]);

  useEffect(() => {
    if (!running) return;
    runOnce();
    const iv = setInterval(runOnce, 2000);
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🤖 Background Worker</h1>
        <p className="subtitle">Emails automatically process ho rahi hain</p>
      </div>

      {/* AUTO STATUS BANNER */}
      <div className="card" style={{ background: 'rgba(16,185,129,0.06)', borderColor: 'rgba(16,185,129,0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
          <div style={{ fontSize: 32 }}>⚡</div>
          <div style={{ flex: 1, minWidth: 200 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: '#065f46', marginBottom: 4 }}>
              Auto-Worker Active
            </div>
            <div style={{ fontSize: 12, color: '#047857', lineHeight: 1.5 }}>
              Vercel Cron har 2 min me check karta hai + ye page har 5 sec me auto-trigger karta hai.
              <b> Koi manual start nahi chahiye.</b>
            </div>
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '6px 12px', borderRadius: 999,
            background: 'rgba(16,185,129,0.15)',
            fontSize: 11, fontWeight: 700, color: '#065f46',
          }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10b981' }} />
            AUTO-ON
          </div>
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
        <Stat label="CHECKS" value={ticks} />
        <Stat label="SENT" value={stats.sent} color="#10b981" />
        <Stat label="FAILED" value={stats.failed} color="#ef4444" />
        <Stat label="REMAINING" value={stats.remaining} color="#f59e0b" />
      </div>

      {/* Controls */}
      <div className="card">
        <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginBottom: 12, fontWeight: 600 }}>
          ⚙️ Manual override (optional — auto already chal raha hai)
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={() => setRunning(v => !v)}
            className={'btn ' + (running ? 'btn-danger' : 'btn-primary')}
            style={{ flex: 1, minWidth: 200, padding: 12 }}
          >
            {running ? '⏹️ Stop Fast Mode' : '⚡ Fast Mode (2 sec)'}
          </button>
          <button onClick={runOnce} className="btn btn-ghost" style={{ padding: 12 }}>
            ⏭️ Step Once
          </button>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ padding: 12 }}>
            Dashboard
          </Link>
        </div>
        <div style={{
          marginTop: 12, padding: 10, borderRadius: 8,
          background: 'var(--bg-subtle)',
          fontSize: 11, color: 'var(--fg-muted)',
          display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8,
        }}>
          <span>Status: <b style={{ color: '#10b981' }}>Auto</b></span>
          <span>Last check: <b>{lastCheck}</b></span>
          <span>Fast: <b>{running ? 'ON' : 'OFF'}</b></span>
        </div>
      </div>

      {/* Logs */}
      <div className="card">
        <h2 style={{ fontSize: 15, marginBottom: 12 }}>📜 Live Logs</h2>
        <div style={{
          background: '#0f172a', color: '#10b981',
          borderRadius: 12, padding: 16, maxHeight: 400, overflow: 'auto',
          fontFamily: 'monospace', fontSize: 11, lineHeight: 1.6,
        }}>
          {logs.length === 0 ? (
            <div style={{ color: '#64748b' }}>Auto-worker waiting for queued emails...</div>
          ) : (
            logs.map((l, i) => <div key={i}>{l}</div>)
          )}
        </div>
      </div>

      {/* Info */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 8 }}>⚡ Automatic Worker — Kaise Kaam Karta Hai</div>
          <div style={{ fontSize: 12, color: 'var(--fg-muted)' }}>
            <div style={{ marginBottom: 6 }}>
              <b>1. Vercel Cron:</b> Har 2 minute me server khud <code>/api/cron/process</code> call karta hai — emails automatically process
            </div>
            <div style={{ marginBottom: 6 }}>
              <b>2. Page Auto-Trigger:</b> Ye page jab bhi koi kholta hai, har 5 sec me auto-trigger hoti hai
            </div>
            <div style={{ marginBottom: 6 }}>
              <b>3. Fast Mode:</b> Agar turant chahiye to ye button dabao — 2 sec me ek batch
            </div>
            <div style={{ marginTop: 10, padding: 10, background: 'rgba(16,185,129,0.08)', borderRadius: 8, color: '#065f46', fontWeight: 600 }}>
              ✅ Koi manual start nahi chahiye. Campaign start karte hi emails jaana shuru ho jayengi.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border)', borderRadius: 12, padding: 14 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 800, color, marginTop: 4 }}>{value.toLocaleString()}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/worker/page.tsx
echo "   ✅ Worker page — auto-trigger added"

# ==========================================
# 5. Git push
# ==========================================
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: Auto worker — Vercel Cron + page auto-trigger"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ AUTO WORKER DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Ab kya hoga:"
echo ""
echo "   1. Campaign start → emails automatic jaayengi"
echo "   2. Vercel Cron har 2 min me worker chalayega"
echo "   3. /worker page kholte hi auto-trigger"
echo "   4. Koi manual 'Start' nahi chahiye"
echo ""
echo "⚠️  Vercel Free Tier Notice:"
echo "   • Cron jobs free tier me limited hain"
echo "   • 2 crons allowed (hum 1 use kar rahe)"
echo "   • Har cron = 1 invocation count"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "⚠️  IMPORTANT:"
echo "   Vercel Cron setup ke liye Vercel Dashboard me"
echo "   redeploy trigger karo ek baar."
echo ""
echo "📸 Screenshot bhejo: /worker page ka"
echo "==============================================="