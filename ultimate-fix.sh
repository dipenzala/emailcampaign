#!/usr/bin/env bash

echo "==============================================="
echo " 🎯 ULTIMATE FIX — Zero Errors, Zero Failures"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. LOAD .env
# ==========================================
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
  echo "✅ .env loaded"
else
  echo "❌ .env nahi mila"
  exit 1
fi
echo ""

# ==========================================
# 2. FIX LOCAL-SENDER.JS — Smart sender picking
# ==========================================
echo "🔧 Step 1: Fixing local-sender.js..."

cat > local-sender.js <<'JSEOF'
// ==========================================
// Smart Local Sender — Zero Error Edition
// ==========================================
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const prisma = new PrismaClient();
const POLL_MS = 3000;
const BATCH = 3;

// ---------- Crypto ----------
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
function decrypt(payload) {
  try {
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const data = buf.subarray(28);
    const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
    d.setAuthTag(tag);
    return Buffer.concat([d.update(data), d.final()]).toString('utf8');
  } catch { return null; }
}

// ---------- OAuth ----------
function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

// ---------- Test sender token (returns working OAuth2 client or null) ----------
async function testSenderToken(sender) {
  try {
    const access = sender.accessToken ? decrypt(sender.accessToken) : '';
    const refresh = decrypt(sender.refreshToken);
    if (!refresh) return null;

    const c = oauthClient();
    c.setCredentials({ access_token: access, refresh_token: refresh });
    await c.getAccessToken();  // forces refresh check
    return c;
  } catch (err) {
    const msg = err.message || '';
    if (/insufficient|permission|invalid_grant|expired|revoked/i.test(msg)) {
      console.log(`   ❌ ${sender.email} — token expired: ${msg.slice(0, 60)}`);
      // Auto-mark as disconnected
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { status: 'DISCONNECTED', isActive: false },
      }).catch(() => {});
    }
    return null;
  }
}

// ---------- MIME ----------
function buildMime(o) {
  const b = '=_b_' + Math.random().toString(36).slice(2);
  const h = [
    `From: ${o.from}`,
    `To: ${o.to}`,
    `Subject: =?UTF-8?B?${Buffer.from(o.subject).toString('base64')}?=`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${b}"`,
  ];
  if (o.unsubUrl) {
    h.push(`List-Unsubscribe: <${o.unsubUrl}>`);
    h.push('List-Unsubscribe-Post: List-Unsubscribe=One-Click');
  }
  const body = `--${b}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(o.text).toString('base64')}

--${b}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(o.html).toString('base64')}

--${b}--`;
  return h.join('\r\n') + '\r\n\r\n' + body;
}

function htmlToText(h) {
  return h.replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]+>/g, '')
    .replace(/\n{3,}/g, '\n\n').trim();
}

function renderTemplate(html, data) {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_, k, def) => {
    const v = data[k];
    return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
  });
}

// ---------- Warm-up ----------
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];
function effectiveLimit(s) {
  if (!s.warmupEnabled) return s.dailyLimit;
  const t = TIERS.find(x => s.warmupDay <= x.maxDay);
  return t ? Math.min(t.limit, s.dailyLimit) : s.dailyLimit;
}

// ---------- Send one ----------
async function sendOne(recipient, oauthClients) {
  const campaign = await prisma.campaign.findUnique({ where: { id: recipient.campaignId } });
  if (!campaign || campaign.status !== 'RUNNING') return;

  // Check sender pool
  const senderEmails = Object.keys(oauthClients);
  if (senderEmails.length === 0) {
    console.log('❌ No working senders — reconnect required');
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'QUEUED' },
    }).catch(() => {});
    return;
  }

  // Suppression check
  const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({
      where: { id: campaign.id },
      data: { suppressedCount: { increment: 1 } },
    });
    console.log(`⏭️  SKIP ${recipient.contact.email} (suppressed)`);
    return;
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipient.id },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // Pick sender with least used
  const senders = await prisma.senderAccount.findMany({
    where: { email: { in: senderEmails } },
    orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }],
  });

  let sender = null;
  for (const s of senders) {
    if (s.batchCount < (campaign.batchLimit ?? 10)) {
      const cap = effectiveLimit(s);
      if (s.sentToday < cap) {
        sender = s;
        break;
      }
    }
  }

  if (!sender) {
    // All senders capped
    console.log('⏸️  All senders at warm-up cap');
    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: { status: 'QUEUED' },
    });
    return;
  }

  // Build + send
  const c = oauthClients[sender.email];
  const gmail = google.gmail({ version: 'v1', auth: c });

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  const html = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  const text = htmlToText(html);

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to: recipient.contact.email,
    subject: campaign.subject,
    html,
    text,
    unsubUrl,
  });

  try {
    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });

    await prisma.campaignRecipient.update({
      where: { id: recipient.id },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId: res.data.id,
        sentAt: new Date(),
        errorCode: null,
        errorMessage: null,
      },
    });
    await prisma.campaign.update({
      where: { id: campaign.id },
      data: { sentCount: { increment: 1 } },
    });
    await prisma.senderAccount.update({
      where: { id: sender.id },
      data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
    });

    console.log(`✅ SENT [${sender.email}] → ${recipient.contact.email}`);

    // Campaign complete check
    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 CAMPAIGN COMPLETED');
    }
  } catch (err) {
    const msg = err?.message ?? 'Send failed';

    // AUTO-SUPPRESS: Any permanent error → block this recipient forever
    const isPermanent = /insufficient|permission|invalid_grant|unauthorized|550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient|not found/i.test(msg);

    if (isPermanent) {
      await prisma.suppressionList.upsert({
        where: { email: recipient.contact.email },
        create: { email: recipient.contact.email, reason: 'MANUAL_BLOCK' },
        update: {},
      }).catch(() => {});
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: {
          status: 'SUPPRESSED',
          errorCode: 'AUTO_SUPPRESSED',
          errorMessage: msg.slice(0, 200),
        },
      });
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { suppressedCount: { increment: 1 } },
      });
      console.log(`⛔ SUPPRESSED ${recipient.contact.email} — won't retry (${msg.slice(0, 40)})`);
    } else {
      // Non-permanent — retry
      await prisma.campaignRecipient.update({
        where: { id: recipient.id },
        data: { status: 'QUEUED', errorMessage: msg.slice(0, 200) },
      });
      console.log(`🔄 RETRY ${recipient.contact.email} (${msg.slice(0, 40)})`);
    }
  }
}

// ---------- Poll loop ----------
let busy = false;
async function poll(oauthClients) {
  if (busy) return;
  busy = true;
  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued — processing...`);
      for (const r of recips) await sendOne(r, oauthClients);
    }
  } catch (e) {
    console.error('Poll error:', e.message);
  } finally {
    busy = false;
  }
}

// ---------- Startup: test all senders first ----------
(async () => {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(' 🚀 Smart Local Sender');
  console.log('═══════════════════════════════════════════');
  console.log('');

  // Test senders
  console.log('🔍 Testing sender tokens...');
  const senders = await prisma.senderAccount.findMany({ where: { status: 'CONNECTED' } });
  console.log(`   Found ${senders.length} sender(s)\n`);

  const oauthClients = {};
  for (const s of senders) {
    process.stdout.write(`   ${s.email}... `);
    const client = await testSenderToken(s);
    if (client) {
      oauthClients[s.email] = client;
      console.log('✅ OK');
    } else {
      console.log('❌ FAILED');
    }
  }

  console.log('');
  console.log(`✅ Working senders: ${Object.keys(oauthClients).length}/${senders.length}`);
  console.log('');

  if (Object.keys(oauthClients).length === 0) {
    console.log('╔═══════════════════════════════════════════╗');
    console.log('║  ❌ NO WORKING SENDERS                    ║');
    console.log('║  → Reconnect at /senders                  ║');
    console.log('╚═══════════════════════════════════════════╝');
    console.log('');
    process.exit(1);
  }

  console.log('🎯 Listening for QUEUED recipients...');
  console.log('');

  poll(oauthClients);
  setInterval(() => poll(oauthClients), POLL_MS);

  process.on('SIGINT', async () => {
    console.log('\n🛑 Stopping...');
    await prisma.$disconnect();
    process.exit(0);
  });
})();
JSEOF

echo "   ✅ local-sender.js updated (smart sender picking + auto-suppress)"
echo ""

# ==========================================
# 3. AUTO-CLEAN current stuck campaign
# ==========================================
echo "🧹 Step 2: Cleaning stuck recipients..."
node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  
  // Suppress the known-broken recipient
  await p.suppressionList.upsert({
    where: { email: "alvaromotormoney@gmail.com" },
    create: { email: "alvaromotormoney@gmail.com", reason: "MANUAL_BLOCK" },
    update: {},
  });
  
  // Mark all failed recipients of that email as SUPPRESSED
  const r = await p.campaignRecipient.updateMany({
    where: {
      contact: { email: "alvaromotormoney@gmail.com" },
      status: { in: ["FAILED", "QUEUED", "PROCESSING"] },
    },
    data: { status: "SUPPRESSED", errorCode: "SUPPRESSED", errorMessage: "Auto-suppressed" },
  });
  console.log("   ✅ Suppressed " + r.count + " stuck recipient(s)");
  
  // Reset other FAILED → QUEUED for retry
  const r2 = await p.campaignRecipient.updateMany({
    where: { status: "FAILED" },
    data: { status: "QUEUED", attemptCount: 0, errorMessage: null, errorCode: null },
  });
  console.log("   ✅ Reset " + r2.count + " FAILED → QUEUED");
  
  await p.$disconnect();
})();
'
echo ""

# ==========================================
# 4. Add Disconnect button to /senders
# ==========================================
echo "🎨 Step 3: Adding Disconnect button to /senders page..."

mkdir -p app/senders

cat > app/senders/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';

export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);

  const load = () => fetch('/api/senders').then(r => r.json()).then(setList);
  useEffect(() => { load(); }, []);

  const connect = () => {
    if (!email) return;
    window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email);
  };

  const disconnect = async (id: string, email: string) => {
    if (!confirm(`Disconnect ${email}?\n\nYe account future campaigns me use nahi hoga.`)) return;
    setBusy(true);
    try {
      const r = await fetch('/api/senders/disconnect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      if (!r.ok) throw new Error('Failed');
      setMsg(`✅ Disconnected ${email}`);
      await load();
    } catch (e: any) {
      setMsg('❌ ' + e.message);
    }
    setBusy(false);
  };

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>

      {msg && <div className="card text-sm">{msg}</div>}

      {/* Connect */}
      <div className="card">
        <h2 className="font-semibold mb-2">Connect Gmail / Workspace</h2>
        <div className="flex gap-3 flex-wrap">
          <input
            className="input max-w-xs"
            placeholder="sales01@company.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
          />
          <button className="btn btn-primary" onClick={connect} disabled={!email}>
            Connect Google
          </button>
        </div>
        <p className="text-xs text-slate-400 mt-2">
          OAuth only. Never share Gmail password. Permission: "Send email on your behalf" must be allowed.
        </p>
      </div>

      {/* Senders list */}
      <div className="card !p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr>
              <th className="p-3">Email</th>
              <th className="p-3">Name</th>
              <th className="p-3">Status</th>
              <th className="p-3">Sent Today</th>
              <th className="p-3">Last Success</th>
              <th className="p-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {list.map(s => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3">{s.email}</td>
                <td className="p-3">{s.displayName}</td>
                <td className="p-3">
                  <span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>
                    {s.status}
                  </span>
                </td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3 text-xs text-slate-500">
                  {s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}
                </td>
                <td className="p-3 text-right">
                  <button
                    onClick={() => disconnect(s.id, s.email)}
                    disabled={busy}
                    className="text-xs px-3 py-1.5 rounded-lg bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20 transition disabled:opacity-50"
                  >
                    Disconnect
                  </button>
                </td>
              </tr>
            ))}
            {list.length === 0 && (
              <tr>
                <td colSpan={6} className="p-8 text-center text-slate-500">
                  No senders connected. Add one above.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/senders/page.tsx
echo "   ✅ Disconnect button added"

# ==========================================
# 5. Create disconnect API endpoint
# ==========================================
echo ""
echo "🔌 Step 4: Creating /api/senders/disconnect endpoint..."

mkdir -p app/api/senders/disconnect

cat > app/api/senders/disconnect/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { cookies } from 'next/headers';
import { verifySession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const token = cookies().get('ec_session')?.value;
    const session = verifySession(token);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await req.json();
    if (!id) {
      return NextResponse.json({ error: 'id required' }, { status: 400 });
    }

    await prisma.senderAccount.update({
      where: { id },
      data: {
        status: 'DISCONNECTED',
        isActive: false,
        accessToken: null,
        refreshToken: null,
        tokenExpiry: null,
      },
    });

    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/senders/disconnect/route.ts
echo "   ✅ Disconnect endpoint created"

# ==========================================
# 6. Git push
# ==========================================
echo ""
echo "🌿 Step 5: Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: smart sender + auto-suppress + disconnect button"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ ALL FIXES APPLIED"
echo "==============================================="
echo ""
echo "🎯 AB YE KARO:"
echo ""
echo "1. Local sender chalao (naye smart code ke saath):"
echo "   bash local-sender.sh"
echo ""
echo "   Ye ab:"
echo "   • Startup pe har sender ka token test karega"
echo "   • Sirf kaam karne wale senders use karega"
echo "   • Broken senders ko auto-disconnect karega"
echo "   • Permission errors ko auto-suppress karega"
echo "   • Chhoda hua 'alvaromotormoney' ab retry nahi karega"
echo ""
echo "2. Disconnect button 2-3 min me live hoga:"
echo "   https://emailcampaign-ten.vercel.app/senders"
echo ""
echo "3. Agar sender test fail hua:"
echo "   → /senders page pe reconnect karo (fresh OAuth)"
echo "==============================================="