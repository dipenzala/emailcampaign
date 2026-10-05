#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🚀 VERCEL WORKER — Manual + Cron"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. PROCESS API — Send batch on-demand
# ==========================================
echo "📝 [1/5] Creating process API..."

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

// ═══════════════════════════════════════════
// SAFE JSON response
// ═══════════════════════════════════════════
function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixelUrl = `${appUrl}/api/track/open/${recipientId}`;
  const pixel = `<img src="${pixelUrl}" width="1" height="1" style="display:none" alt="" />`;
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

  // Save to Sent folder
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

export async function GET() { return processBatch(); }
export async function POST() { return processBatch(); }

async function processBatch() {
  const t0 = Date.now();
  const MAX_BATCH = 10; // Process 10 emails per invocation

  const results: any = {
    ok: true,
    processed: 0,
    sent: 0,
    failed: 0,
    bounced: 0,
    suppressed: 0,
    errors: [],
    elapsed: 0,
  };

  try {
    // Get next QUEUED recipients
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
      return json({ ...results, message: 'No queued recipients' });
    }

    console.log('[worker] Processing', recips.length, 'recipients');

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        // Suppression check
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

        console.log('[worker] Sender:', sender.email, '| To:', contact.email);

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

        // Update campaign
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });

        // Update sender
        await markSenderUsed(sender.id);

        // Save refreshed tokens
        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          });
        }

        results.sent++;
        console.log('[worker] ✅ SENT:', contact.email);

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
        console.error('[worker] ❌', r.contact.email, '|', msg);
      }
    }

    results.elapsed = Date.now() - t0;

    // Count remaining
    const remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.remaining = remaining;

    console.log('[worker] Batch done:', results);

    return json(results);
  } catch (err: any) {
    console.error('[worker] FATAL:', err);
    return json({
      ok: false,
      error: err?.message || 'Server error',
      processed: results.processed,
      sent: results.sent,
    }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/process/route.ts
echo "   ✅ /api/worker/process"

# ==========================================
# 2. AUTO-PROCESS PAGE (Dashboard button)
# ==========================================
echo ""
echo "📝 [2/5] Creating auto-process page..."

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

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/process', { method: 'POST' });
      const j = await r.json();

      setTicks(t => t + 1);
      setStats(prev => ({
        sent: prev.sent + (j.sent ?? 0),
        failed: prev.failed + (j.failed ?? 0),
        processed: prev.processed + (j.processed ?? 0),
        remaining: j.remaining ?? 0,
      }));

      const time = new Date().toLocaleTimeString();
      const msg = j.message || `✅ ${j.sent || 0} sent | ❌ ${j.failed || 0} failed | 📬 ${j.remaining ?? 0} remaining`;
      setLogs(prev => [`[${time}] ${msg}`, ...prev.slice(0, 49)]);

      // Auto-stop if no remaining
      if (j.remaining === 0 && j.processed === 0) {
        setLogs(prev => [`[${time}] 🎉 All emails processed!`, ...prev]);
        setRunning(false);
      }
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev.slice(0, 49)]);
    }
  };

  useEffect(() => {
    if (!running) return;
    runOnce();
    const iv = setInterval(runOnce, 3000);
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="space-y-5">
      <div className="page-header">
        <h1>🤖 Background Worker</h1>
        <p className="subtitle">Vercel pe hi emails process hongi</p>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
        <Stat label="TICKS" value={ticks} />
        <Stat label="SENT" value={stats.sent} color="#10b981" />
        <Stat label="FAILED" value={stats.failed} color="#ef4444" />
        <Stat label="REMAINING" value={stats.remaining} color="#f59e0b" />
      </div>

      {/* Controls */}
      <div className="card">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={() => setRunning(v => !v)}
            className={'btn ' + (running ? 'btn-danger' : 'btn-primary')}
            style={{ flex: 1, padding: 14, fontSize: 15 }}
          >
            {running ? '⏹️ Stop Worker' : '▶️ Start Worker'}
          </button>
          <button onClick={runOnce} className="btn btn-ghost" style={{ padding: 14 }}>
            ⏭️ Step Once
          </button>
          <Link href="/dashboard/live" className="btn btn-ghost" style={{ padding: 14 }}>
            Dashboard
          </Link>
        </div>

        <div style={{
          marginTop: 12, padding: 12, borderRadius: 10,
          background: running ? 'rgba(16,185,129,0.08)' : 'rgba(100,116,139,0.08)',
          border: '1px solid ' + (running ? 'rgba(16,185,129,0.3)' : 'rgba(100,116,139,0.2)'),
          fontSize: 12,
          color: running ? '#065f46' : '#475569',
          fontWeight: 600,
        }}>
          {running ? '🟢 Worker running — processing 10 emails every 3 seconds' : '⚪ Worker stopped'}
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
            <div style={{ color: '#64748b' }}>Click "Start Worker" to begin...</div>
          ) : (
            logs.map((l, i) => <div key={i}>{l}</div>)
          )}
        </div>
      </div>

      {/* Info */}
      <div className="card" style={{ background: 'rgba(59,130,246,0.05)', borderColor: 'rgba(59,130,246,0.2)' }}>
        <div style={{ fontSize: 13, color: '#1e40af', lineHeight: 1.7 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>💡 Kaise Use Karo</div>
          <ol style={{ margin: 0, paddingLeft: 20, fontSize: 12, color: 'var(--fg-muted)' }}>
            <li>Campaign create karo (dashboard se)</li>
            <li>Ye page kholo</li>
            <li><b>"Start Worker"</b> click karo</li>
            <li>Emails automatically jaayengi (10 har 3 sec)</li>
            <li>Page open rakho jab tak campaign khatam ho</li>
          </ol>
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
echo "   ✅ /worker page (Vercel) — manual worker"

# ==========================================
# 3. SIDEBAR — Add Worker link
# ==========================================
echo ""
echo "🎨 [3/5] Adding Worker to sidebar..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'components/Sidebar.tsx';
if (!fs.existsSync(f)) { console.log('   ⚠️  Sidebar not found'); process.exit(0); }

let c = fs.readFileSync(f, 'utf8');

if (!c.includes('/worker')) {
  c = c.replace(
    /\{ href: '\/settings', label: 'Settings', icon: '⚙️' \},/,
    `{ href: '/worker', label: 'Worker', icon: '🤖' },
      { href: '/settings', label: 'Settings', icon: '⚙️' },`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Worker link added to sidebar');
NODEEOF

# ==========================================
# 4. HEALTH API — Add worker status
# ==========================================
echo ""
echo "📝 [4/5] Adding worker status to health API..."

mkdir -p app/api/health

cat > app/api/health/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  try {
    const queued = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });

    const lastSent = await prisma.campaignRecipient.findFirst({
      where: { status: 'SENT' },
      orderBy: { sentAt: 'desc' },
      select: { sentAt: true },
    });

    return NextResponse.json({
      ok: true,
      ts: Date.now(),
      domain: process.env.APP_URL || 'http://localhost:3000',
      queue: {
        pending: queued,
        lastSentAt: lastSent?.sentAt || null,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/health/route.ts
echo "   ✅ Health API updated"

# ==========================================
# 5. GIT PUSH
# ==========================================
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: Vercel-based worker (/worker page) — no Northflank needed"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ VERCEL WORKER DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Naya Flow:"
echo ""
echo "   1. Campaign banao (/campaigns/new)"
echo "   2. /worker kholo"
echo "   3. '▶️ Start Worker' click karo"
echo "   4. Emails automatically jaayengi"
echo ""
echo "💡 Kaise kaam karta hai:"
echo "   • Har 3 sec me 10 emails process karega"
echo "   • Page open rakho jab tak campaign khatam"
echo "   • Northflank ki zaroorat nahi"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "URL: https://emailcampaign-ten.vercel.app/worker"
echo "==============================================="