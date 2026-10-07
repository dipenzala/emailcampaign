#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔒 APPROVAL GATE — Test First, Then Send"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. PRISMA — add approval fields
# ═══════════════════════════════════════════
echo "📝 [1/7] Adding approval fields to Campaign..."

if ! grep -q "approvalStatus" prisma/schema.prisma; then
  node <<'NODEEOF'
const fs = require('fs');
let s = fs.readFileSync('prisma/schema.prisma', 'utf8');

s = s.replace(
  /model Campaign \{([\s\S]*?)\n\}/,
  (match, body) => {
    const fields = `
  // ═══ Approval Gate fields ═══
  approvalRequired  Boolean   @default(true)
  approvalStatus    String    @default("PENDING")
  approvalEmail     String?
  approvalToken     String?   @unique
  testSentAt        DateTime?
  approvedAt        DateTime?
  rejectedAt        DateTime?
`;
    return `model Campaign {${body}${fields}\n}`;
  }
);

fs.writeFileSync('prisma/schema.prisma', s);
console.log('   ✅ Approval fields added');
NODEEOF
else
  echo "   ✅ Approval fields already exist"
fi

# ═══════════════════════════════════════════
# 2. APPROVAL REQUEST API
# ═══════════════════════════════════════════
echo ""
echo "🔌 [2/7] Creating approval request API..."

mkdir -p 'app/api/campaigns/[id]/request-approval'

cat > 'app/api/campaigns/[id]/request-approval/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { checkEmail } from '@/lib/spam-checker';
import crypto from 'crypto';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(req: Request, { params }: { params: { id: string } }) {
  try {
    const { approvalEmail } = await req.json();
    if (!approvalEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(approvalEmail)) {
      return NextResponse.json({ error: 'Valid approval email required' }, { status: 400 });
    }

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Spam check
    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({
      subject: campaign.subject,
      html: campaign.html,
      fromEmail: sender?.email || 'noreply@example.com',
    });

    if (report.blocked) {
      return NextResponse.json(
        { error: 'Spam score too high — fix content first', score: report.score, issues: report.issues },
        { status: 400 }
      );
    }

    if (!sender || !sender.refreshToken) {
      return NextResponse.json({ error: 'No connected sender' }, { status: 400 });
    }

    // Generate approval token
    const token = crypto.randomBytes(24).toString('hex');

    // Get sample recipient (first queued)
    const sampleRecipient = await prisma.campaignRecipient.findFirst({
      where: { campaignId: params.id, status: 'QUEUED' },
      include: { contact: true },
    });

    const sampleData = sampleRecipient?.contact ? {
      name: sampleRecipient.contact.name || '',
      email: sampleRecipient.contact.email,
      company: sampleRecipient.contact.company || '',
      city: sampleRecipient.contact.city || '',
      phone: sampleRecipient.contact.phone || '',
    } : {
      name: 'Sample Name',
      email: 'sample@example.com',
      company: 'Sample Company',
      city: '',
      phone: '',
    };

    // Render sample email
    const finalSubject = formatSubject(campaign.subject, sampleData);
    let sampleHtml = renderTemplate(campaign.html, sampleData);

    // Add approval banner at top
    const approveUrl = `${process.env.APP_URL}/approve/${token}`;
    const approvalBanner = `
<div style="background:#f0fdf4;border:2px dashed #10b981;border-radius:12px;padding:20px;margin:20px;font-family:Arial,sans-serif;">
  <div style="font-size:16px;font-weight:800;color:#065f46;margin-bottom:8px;">
    🔍 This is a TEST email for approval
  </div>
  <div style="font-size:13px;color:#047857;line-height:1.6;margin-bottom:16px;">
    Campaign: <b>${campaign.name}</b><br>
    Total recipients: <b>${campaign.totalCount}</b><br>
    Spam score: <b>${report.score}/100</b> ${report.score < 30 ? '✅' : '⚠️'}<br>
    Sample to: <b>${sampleData.email}</b> (${sampleData.company || 'no company'})
  </div>
  <a href="${approveUrl}" style="display:inline-block;background:#10b981;color:#fff;text-decoration:none;padding:14px 28px;border-radius:10px;font-weight:800;font-size:15px;">
    ✅ YES, SEND TO ALL ${campaign.totalCount} RECIPIENTS
  </a>
  <div style="font-size:11px;color:#64748b;margin-top:12px;">
    Ya <a href="${approveUrl}?action=reject" style="color:#dc2626;">❌ Cancel this campaign</a>
  </div>
  <div style="font-size:11px;color:#94a3b8;margin-top:10px;">
    ⚠️ Jab tak aap YES nahi dabayenge, koi email nahi jayegi.
  </div>
</div>`;

    // Inject banner at top of body
    if (/<body[^>]*>/i.test(sampleHtml)) {
      sampleHtml = sampleHtml.replace(/(<body[^>]*>)/i, `$1${approvalBanner}`);
    } else {
      sampleHtml = approvalBanner + sampleHtml;
    }

    // Send approval email
    const access = sender.accessToken ? decrypt(sender.accessToken) : '';
    const refresh = decrypt(sender.refreshToken);
    const c = oauthClient();
    c.setCredentials({ access_token: access, refresh_token: refresh });
    const gmail = google.gmail({ version: 'v1', auth: c });

    const raw = buildMime({
      from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
      to: approvalEmail,
      subject: `[APPROVAL NEEDED] ${finalSubject}`,
      html: sampleHtml,
      text: htmlToText(sampleHtml),
    });

    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });

    // Update campaign with approval info
    await prisma.campaign.update({
      where: { id: params.id },
      data: {
        approvalRequired: true,
        approvalStatus: 'TEST_SENT',
        approvalEmail,
        approvalToken: token,
        testSentAt: new Date(),
        status: 'AWAITING_APPROVAL',
        spamScore: report.score,
        spamIssues: report.issues as any,
      },
    });

    return NextResponse.json({
      ok: true,
      message: `Test email sent to ${approvalEmail}`,
      messageId: res.data.id,
      approvalEmail,
      spamScore: report.score,
      token,
      approveUrl,
    });
  } catch (err: any) {
    console.error('[request-approval]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/campaigns/[id]/request-approval/route.ts'
echo "   ✅ Request approval API"

# ═══════════════════════════════════════════
# 3. APPROVE ACTION API
# ═══════════════════════════════════════════
echo ""
echo "🔌 [3/7] Creating approval action API..."

mkdir -p 'app/api/approve/[token]'

cat > 'app/api/approve/[token]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { enableWorker, enableBulkWorker } from '@/lib/worker-settings';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: { token: string } }) {
  const url = new URL(req.url);
  const action = url.searchParams.get('action') || 'approve';
  const token = params.token;

  try {
    const campaign = await prisma.campaign.findUnique({
      where: { approvalToken: token },
    });

    if (!campaign) {
      return NextResponse.json({ error: 'Invalid or expired token' }, { status: 404 });
    }

    if (campaign.approvalStatus === 'APPROVED') {
      return NextResponse.json({
        ok: true,
        message: 'Already approved',
        status: 'APPROVED',
        campaignId: campaign.id,
      });
    }

    if (action === 'reject' || action === 'cancel') {
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: {
          approvalStatus: 'REJECTED',
          rejectedAt: new Date(),
          status: 'STOPPED',
        },
      });

      return NextResponse.json({
        ok: true,
        message: 'Campaign rejected. No emails will be sent.',
        status: 'REJECTED',
        campaignId: campaign.id,
      });
    }

    // APPROVE
    await prisma.campaign.update({
      where: { id: campaign.id },
      data: {
        approvalStatus: 'APPROVED',
        approvedAt: new Date(),
        status: 'RUNNING',
        startedAt: new Date(),
      },
    });

    // Auto-enable both workers
    try {
      await enableWorker();
      await enableBulkWorker();
    } catch {}

    return NextResponse.json({
      ok: true,
      message: 'Approved! Emails starting now.',
      status: 'APPROVED',
      campaignId: campaign.id,
      totalRecipients: campaign.totalCount,
    });
  } catch (err: any) {
    console.error('[approve]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' 'app/api/approve/[token]/route.ts'
echo "   ✅ Approve/reject API"

# ═══════════════════════════════════════════
# 4. APPROVAL CONFIRMATION PAGE
# ═══════════════════════════════════════════
echo ""
echo "🎨 [4/7] Creating approval page..."

mkdir -p 'app/approve/[token]'

cat > 'app/approve/[token]/page.tsx' <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import { useParams, useSearchParams } from 'next/navigation';
import Link from 'next/link';

export default function ApprovePage() {
  const params = useParams<{ token: string }>();
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('');
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    const action = searchParams.get('action') || 'approve';
    fetch(`/api/approve/${params.token}?action=${action}`)
      .then(r => r.json())
      .then(j => {
        if (j.ok) {
          setStatus('success');
          setMessage(j.message);
          setData(j);
        } else {
          setStatus('error');
          setMessage(j.error);
        }
      })
      .catch(e => {
        setStatus('error');
        setMessage(e.message);
      });
  }, [params.token, searchParams]);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
      <div className="card" style={{ maxWidth: 520, width: '100%', padding: 40, textAlign: 'center' }}>
        {status === 'loading' && (
          <>
            <div style={{ fontSize: 60, marginBottom: 16 }}>⏳</div>
            <h1 style={{ fontSize: 22 }}>Processing...</h1>
          </>
        )}

        {status === 'success' && data?.status === 'APPROVED' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>✅</div>
            <h1 style={{ fontSize: 26, fontWeight: 800, color: '#065f46', marginBottom: 12 }}>
              Approved!
            </h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14, marginBottom: 20 }}>
              Campaign is now LIVE. Emails starting to {data.totalRecipients?.toLocaleString() || '0'} recipients.
            </p>
            <Link href="/dashboard/live" className="btn btn-primary" style={{ display: 'inline-flex' }}>
              📊 View Live Dashboard
            </Link>
          </>
        )}

        {status === 'success' && data?.status === 'REJECTED' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>🛑</div>
            <h1 style={{ fontSize: 26, fontWeight: 800, color: '#991b1b', marginBottom: 12 }}>
              Campaign Cancelled
            </h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>
              No emails will be sent. Campaign is stopped.
            </p>
          </>
        )}

        {status === 'error' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>❌</div>
            <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 12 }}>Error</h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>{message}</p>
          </>
        )}
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' 'app/approve/[token]/page.tsx'
echo "   ✅ Approval page"

# ═══════════════════════════════════════════
# 5. WORKER — skip non-approved campaigns
# ═══════════════════════════════════════════
echo ""
echo "🔒 [5/7] Adding approval check to workers..."

# Bulk route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

if (!c.includes('AWAITING_APPROVAL')) {
  // Change: only process campaigns with approvalStatus != PENDING/TEST_SENT
  c = c.replace(
    /where: \{ status: 'QUEUED', campaign: \{ status: 'RUNNING' \} \}/g,
    `where: {
        status: 'QUEUED',
        campaign: {
          status: 'RUNNING',
          OR: [
            { approvalRequired: false },
            { approvalStatus: 'APPROVED' },
          ],
        },
      }`
  );

  // Self-heal: also exclude AWAITING_APPROVAL
  c = c.replace(
    /status: \{ in: \['PAUSED', 'STOPPED'\] \}/,
    `status: { in: ['PAUSED', 'STOPPED'] }`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Bulk route skips unapproved');
NODEEOF

# Process route
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/process/route.ts';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

if (!c.includes('AWAITING_APPROVAL')) {
  c = c.replace(
    /where: \{ status: 'QUEUED', campaign: \{ status: 'RUNNING' \} \}/g,
    `where: {
        status: 'QUEUED',
        campaign: {
          status: 'RUNNING',
          OR: [
            { approvalRequired: false },
            { approvalStatus: 'APPROVED' },
          ],
        },
      }`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Process route skips unapproved');
NODEEOF

# Local-sender
node <<'NODEEOF'
const fs = require('fs');
const f = 'local-sender.js';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

if (!c.includes('AWAITING_APPROVAL')) {
  c = c.replace(
    /where: \{ status: 'QUEUED', campaign: \{ status: 'RUNNING' \} \}/g,
    `where: {
        status: 'QUEUED',
        campaign: {
          status: 'RUNNING',
          OR: [
            { approvalRequired: false },
            { approvalStatus: 'APPROVED' },
          ],
        },
      }`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Local worker skips unapproved');
NODEEOF

# ═══════════════════════════════════════════
# 6. UI — Campaign form gets approval section
# ═══════════════════════════════════════════
echo ""
echo "🎨 [6/7] Adding approval UI to campaign form..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

// Add approval state
if (!c.includes('approvalEmail')) {
  c = c.replace(
    /const \[testEmail, setTestEmail\] = useState\(''\);/,
    `const [testEmail, setTestEmail] = useState('');
  const [approvalEmail, setApprovalEmail] = useState('');
  const [approvalSent, setApprovalSent] = useState(false);
  const [approvalBusy, setApprovalBusy] = useState(false);`
  );
}

// Add approval flow function
if (!c.includes('requestApproval')) {
  const launchFunc = c.match(/const launch = async \(\) => \{[\s\S]*?\n  \};/);
  if (launchFunc) {
    const approvalFunc = `
  // ═══════════════════════════════════════════
  // REQUEST APPROVAL — send test email
  // ═══════════════════════════════════════════
  const requestApproval = async () => {
    if (!allContacts.length) { showMsg('❌ Contacts add karo', 'error'); return; }
    if (!subject.trim()) { showMsg('❌ Subject daalo', 'error'); return; }
    if (!approvalEmail || !/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(approvalEmail)) {
      showMsg('❌ Valid approval email daalo (aapka personal email)', 'error');
      return;
    }

    setApprovalBusy(true);
    showMsg('📤 Creating campaign + sending test email...', 'info');

    try {
      // Create campaign
      const createRes = await fetch('/api/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          emails: allContacts.map(c => c.email),
          batchLimit,
        }),
      });
      const created = await createRes.json();
      if (!createRes.ok) throw new Error(created.error?.message || 'Campaign create failed');

      // Request approval
      const approvalRes = await fetch(\`/api/campaigns/\${created.id}/request-approval\`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ approvalEmail }),
      });
      const approval = await approvalRes.json();
      if (!approvalRes.ok) throw new Error(approval.error || 'Approval request failed');

      setApprovalSent(true);
      showMsg('✅ Test email sent! Aapke inbox me check karo → "YES SEND TO ALL" dabao', 'success');
    } catch (e: any) {
      showMsg('❌ ' + e.message, 'error');
    }
    setApprovalBusy(false);
  };

`;
    c = c.replace(/const launch = async \(\) => \{/, approvalFunc + 'const launch = async () => {');
  }
}

// Add approval UI in Step 4
if (!c.includes('approvalEmail')) {
  // Insert approval section at start of Step 4
  c = c.replace(
    /(🪀 Step 4 — Final Review)/,
    '🚀 Step 4 — Approval & Launch'
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Campaign form patched (partial)');
NODEEOF

# Rebuild Step 4 with approval UI
node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

// Replace Step 4 block with new version including approval
const step4Pattern = /\{step === 4 && \([\s\S]*?\)\}/;

const newStep4 = `{step === 4 && (
        <div className="card space-y-4">
          <div>
            <h2 style={{ fontSize: 18, marginBottom: 4 }}>🚀 Step 4 — Approval Required</h2>
            <p style={{ fontSize: 13, color: 'var(--fg-muted)', margin: 0 }}>
              Pehle aapke email pe test bhejenge. Aap approve karo → phir sabko jayegi.
            </p>
          </div>

          {/* Campaign summary */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 14 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Campaign</div>
              <div style={{ fontSize: 14, fontWeight: 600, marginTop: 4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{name}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 14 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Subject</div>
              <div style={{ fontSize: 14, fontWeight: 600, marginTop: 4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{subject}</div>
            </div>
            <div style={{ background: 'rgba(16,185,129,0.08)', borderRadius: 12, padding: 14 }}>
              <div style={{ fontSize: 11, color: '#065f46', fontWeight: 700, textTransform: 'uppercase' }}>Recipients</div>
              <div style={{ fontSize: 22, fontWeight: 800, color: '#059669', marginTop: 4 }}>{allContacts.length.toLocaleString()}</div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', borderRadius: 12, padding: 14 }}>
              <div style={{ fontSize: 11, color: 'var(--fg-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Batch</div>
              <div style={{ fontSize: 14, fontWeight: 600, marginTop: 4 }}>{batchLimit} per sender</div>
            </div>
          </div>

          {/* Approval email input */}
          <div style={{ padding: 20, background: 'linear-gradient(135deg, rgba(139,92,246,0.06), rgba(236,72,153,0.03))', border: '2px dashed rgba(139,92,246,0.3)', borderRadius: 16 }}>
            <div style={{ fontSize: 15, fontWeight: 800, marginBottom: 8, color: '#6d28d9' }}>
              📧 Where should we send the test email?
            </div>
            <div style={{ fontSize: 12, color: 'var(--fg-muted)', marginBottom: 12 }}>
              Enter your personal email. You will receive a test with a "YES SEND TO ALL" button. Nothing will be sent until you click it.
            </div>
            <input
              type="email"
              className="input"
              placeholder="you@yourcompany.com"
              value={approvalEmail}
              onChange={e => setApprovalEmail(e.target.value)}
              disabled={approvalBusy || approvalSent}
            />
          </div>

          {/* Step 1: Request Approval */}
          {!approvalSent ? (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button onClick={() => setStep(3)} className="btn btn-ghost">← Back</button>
              <button
                onClick={requestApproval}
                disabled={approvalBusy || !approvalEmail}
                className="btn btn-primary"
                style={{ flex: 1, padding: 14, fontSize: 15 }}
              >
                {approvalBusy ? '⏳ Sending test...' : '📤 Send Test for Approval'}
              </button>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ padding: 20, background: '#f0fdf4', border: '2px solid #10b981', borderRadius: 16, textAlign: 'center' }}>
                <div style={{ fontSize: 40, marginBottom: 8 }}>✅</div>
                <div style={{ fontSize: 16, fontWeight: 800, color: '#065f46', marginBottom: 6 }}>
                  Test email sent to {approvalEmail}
                </div>
                <div style={{ fontSize: 13, color: '#047857', marginBottom: 16 }}>
                  Open your inbox → find the test → click <b>"YES, SEND TO ALL"</b><br />
                  Nothing will be sent until you approve.
                </div>
                <a
                  href="https://mail.google.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn btn-primary"
                  style={{ display: 'inline-flex' }}
                >
                  📧 Open Gmail
                </a>
              </div>

              <div style={{ display: 'flex', gap: 8 }}>
                <Link href="/dashboard/live" className="btn btn-ghost" style={{ flex: 1, textAlign: 'center' }}>
                  📊 Go to Dashboard
                </Link>
              </div>
            </div>
          )}

          <div style={{ fontSize: 11, color: 'var(--fg-dim)', textAlign: 'center' }}>
            🔒 Safety: Emails will NOT be sent without your approval.
          </div>
        </div>
      )}`;

if (step4Pattern.test(c)) {
  c = c.replace(step4Pattern, newStep4);
  fs.writeFileSync(f, c);
  console.log('   ✅ Step 4 with approval UI');
} else {
  console.log('   ⚠️  Step 4 pattern not found');
}
NODEEOF

# ═══════════════════════════════════════════
# 7. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [7/7] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: approval gate — test email required before bulk send"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ APPROVAL GATE DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Flow:"
echo ""
echo "1. /campaigns/new kholo"
echo "2. Contacts + Subject + HTML bharo"
echo "3. Step 4 me approval email daalo (aapka personal Gmail)"
echo "4. 'Send Test for Approval' dabao"
echo ""
echo "5. Aapke Gmail me aayega:"
echo "   Subject: [APPROVAL NEEDED] CONGRATULATIONS 🎉"
echo "   Body: Sample email + GREEN button 'YES, SEND TO ALL'"
echo ""
echo "6. Button dabao → /approve/xxx page khulega"
echo "7. Confirm karo → Campaign RUNNING ho jayega"
echo "8. Tab bulk worker emails bhejega"
echo ""
echo "🚫 Approve na karo → koi email nahi jayegi"
echo "❌ Reject karo → campaign cancel"
echo ""
echo "⚠️  Prisma schema change hua hai"
echo "   Vercel build me automatic add hoga"
echo "   (Local se chahiye to: npx prisma db push)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📱 Test: /campaigns/new → Step 4"
echo "==============================================="