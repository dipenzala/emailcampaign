#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎯 FINAL FIX: Subject Personalization Everywhere"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. REWRITE PERSONALIZATION LIB (clean)
# ═══════════════════════════════════════════
echo "📝 [1/6] Rewriting personalization lib..."

cat > lib/personalization.ts <<'EOF'
// ═══════════════════════════════════════════
// PERSONALIZATION — clean & reliable
// ═══════════════════════════════════════════

/**
 * Replace {{variable}} in template.
 */
export function renderTemplate(template: string, data: Record<string, any>): string {
  if (!template) return '';
  return template.replace(
    /\{\{\s*(\w+)(?:\s*\|\s*default\s*:\s*"([^"]*)")?\s*\}\}/g,
    (_m, key, def) => {
      const v = data[key];
      if (v === undefined || v === null || v === '') return def ?? '';
      return String(v);
    }
  );
}

/**
 * Get display label from contact.
 * Priority: name → company → email prefix
 */
export function getDisplayLabel(contact: {
  name?: string | null;
  company?: string | null;
  email?: string | null;
}): string {
  const name = String(contact?.name || '').trim();
  if (name) return name;

  const company = String(contact?.company || '').trim();
  if (company) return company;

  const email = String(contact?.email || '').trim();
  if (!email) return 'Friend';

  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';

  return clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
}

/**
 * ⭐ Format subject with recipient label.
 *
 * Rules:
 *  1. Subject has {{name}} or {{company}} → render directly
 *  2. Subject starts with "CONGRATULATIONS" → prepend label
 *  3. Else → "CONGRATULATIONS 🎉 [Label] — original subject"
 */
export function formatSubject(
  subjectTemplate: string,
  contact: { name?: string | null; company?: string | null; email?: string | null }
): string {
  if (!subjectTemplate) return '';

  const label = getDisplayLabel(contact);
  const subject = subjectTemplate.trim();

  // Rule 1: Has variable
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }

  // Rule 2: Already starts with CONGRATULATIONS
  if (/^congratulations/i.test(subject)) {
    const rest = subject
      .replace(/^congratulations[\s🎉🎊!.,]*/i, '')
      .trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${label} — ${rest}`
      : `CONGRATULATIONS 🎉 ${label}`;
  }

  // Rule 3: Prepend prefix
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

/**
 * Full personalization (subject + html).
 */
export function personalize(
  contact: { name?: string | null; company?: string | null; email?: string | null; city?: string | null; phone?: string | null },
  subjectTemplate: string,
  htmlTemplate: string
) {
  return {
    subject: formatSubject(subjectTemplate, contact),
    html: renderTemplate(htmlTemplate, {
      name: contact.name || '',
      email: contact.email || '',
      company: contact.company || '',
      city: contact.city || '',
      phone: contact.phone || '',
    }),
  };
}
EOF
sed -i 's/\r$//' lib/personalization.ts
echo "   ✅ personalization.ts rewritten"

# ═══════════════════════════════════════════
# 2. REWRITE BULK ROUTE — uses formatSubject
# ═══════════════════════════════════════════
echo ""
echo "📝 [2/6] Rewriting bulk route..."

mkdir -p app/api/worker/bulk

cat > app/api/worker/bulk/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

export async function GET(req: Request) { return handle(req); }
export async function POST(req: Request) { return handle(req); }

async function handle(req: Request) {
  const t0 = Date.now();
  const results: any = {
    ok: true, processed: 0, sent: 0, failed: 0, bounced: 0,
    suppressed: 0, remaining: 0, errors: [] as string[], elapsed: 0,
  };

  try {
    const url = new URL(req.url);
    const BATCH = Math.min(50, Math.max(1, parseInt(url.searchParams.get('batch') || '5', 10) || 5));
    results.batchSize = BATCH;

    // Self-heal
    try {
      const twoMinAgo = new Date(Date.now() - 2 * 60 * 1000);
      await prisma.campaignRecipient.updateMany({
        where: { status: 'PROCESSING', queuedAt: { lt: twoMinAgo } },
        data: { status: 'QUEUED' },
      });
      await prisma.campaign.updateMany({
        where: { status: { in: ['PAUSED', 'STOPPED'] }, recipients: { some: { status: 'QUEUED' } } },
        data: { status: 'RUNNING' },
      });
    } catch {}

    // Fetch queued with contact
    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true, campaign: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      results.elapsed = Date.now() - t0;
      return j({ ...results, message: 'No queued recipients' });
    }

    // Process each
    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

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

        // Pick sender
        const sender = await pickNextSenderStrict({ batchLimit: campaign.batchLimit ?? 1 });
        if (!sender) {
          results.errors.push('No sender available');
          break;
        }

        // Mark processing
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        // ═══════════════════════════════════════════
        // BUILD EMAIL with formatSubject
        // ═══════════════════════════════════════════
        const recipientData = {
          name: contact.name || '',
          email: contact.email,
          company: contact.company || '',
          city: contact.city || '',
          phone: contact.phone || '',
        };

        // Format subject
        const finalSubject = formatSubject(campaign.subject, recipientData);

        // Render HTML
        let html = renderTemplate(campaign.html, recipientData);

        // Tracking pixel
        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        // Unsubscribe URL
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

        console.log(`[bulk] To: ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

        // Send
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: contact.email,
          subject: finalSubject,  // ← formatted subject
          html,
          text: htmlToText(html),
          unsubscribeUrl: unsubUrl,
        });

        const res = await gmail.users.messages.send({
          userId: 'me',
          requestBody: { raw: Buffer.from(raw).toString('base64url') },
        });

        // Save to Sent
        try {
          if (res.data.id) {
            await gmail.users.messages.modify({
              userId: 'me',
              id: res.data.id,
              requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
            });
          }
        } catch {}

        // Update DB
        await prisma.campaignRecipient.update({
          where: { id: r.id },
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
        await markSenderUsed(sender.id);

        results.sent++;
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
          }).catch(() => {});
          results.bounced++;
        } else {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: {
              status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
              errorMessage: msg.slice(0, 200),
            },
          }).catch(() => {});
          results.failed++;
        }
        results.errors.push(msg.slice(0, 150));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    console.error('[bulk] FATAL:', err);
    return j({ ok: false, error: err?.message || 'Server error', ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/bulk/route.ts
echo "   ✅ Bulk route — uses formatSubject"

# ═══════════════════════════════════════════
# 3. REWRITE PROCESS ROUTE — same logic
# ═══════════════════════════════════════════
echo ""
echo "📝 [3/6] Rewriting process route..."

mkdir -p app/api/worker/process

cat > app/api/worker/process/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

function j(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

export async function GET() { return handle(); }
export async function POST() { return handle(); }

async function handle() {
  const t0 = Date.now();
  const results: any = { ok: true, processed: 0, sent: 0, failed: 0, remaining: 0, errors: [], elapsed: 0 };

  try {
    // Self-heal
    try {
      const twoMinAgo = new Date(Date.now() - 2 * 60 * 1000);
      await prisma.campaignRecipient.updateMany({
        where: { status: 'PROCESSING', queuedAt: { lt: twoMinAgo } },
        data: { status: 'QUEUED' },
      });
      await prisma.campaign.updateMany({
        where: { status: { in: ['PAUSED', 'STOPPED'] }, recipients: { some: { status: 'QUEUED' } } },
        data: { status: 'RUNNING' },
      });
    } catch {}

    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true, campaign: true },
      take: 3,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      results.elapsed = Date.now() - t0;
      return j({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

        const sup = await prisma.suppressionList.findUnique({ where: { email: contact.email } });
        if (sup) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
          });
          continue;
        }

        const sender = await pickNextSenderStrict({ batchLimit: campaign.batchLimit ?? 1 });
        if (!sender) { results.errors.push('No sender'); break; }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        const recipientData = {
          name: contact.name || '',
          email: contact.email,
          company: contact.company || '',
          city: contact.city || '',
          phone: contact.phone || '',
        };

        const finalSubject = formatSubject(campaign.subject, recipientData);
        let html = renderTemplate(campaign.html, recipientData);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

        console.log(`[process] ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: contact.email,
          subject: finalSubject,
          html,
          text: htmlToText(html),
          unsubscribeUrl: unsubUrl,
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

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: {
            status: 'SENT',
            senderAccountId: sender.id,
            providerMessageId: res.data.id,
            sentAt: new Date(),
          },
        });
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });
        await markSenderUsed(sender.id);
        results.sent++;
      } catch (err: any) {
        const msg = err?.message ?? 'failed';
        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: {
            status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
            errorMessage: msg.slice(0, 200),
          },
        }).catch(() => {});
        results.failed++;
        results.errors.push(msg.slice(0, 150));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    return j({ ok: false, error: err?.message, ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/process/route.ts
echo "   ✅ Process route — uses formatSubject"

# ═══════════════════════════════════════════
# 4. REWRITE WORKER/TICK — same logic
# ═══════════════════════════════════════════
echo ""
echo "📝 [4/6] Rewriting worker/tick route..."

mkdir -p app/api/worker/tick

cat > app/api/worker/tick/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function GET() { return handle(); }
export async function POST() { return handle(); }

async function handle() {
  const results: any = { ok: true, processed: 0, sent: 0, failed: 0, remaining: 0, errors: [] };

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true, campaign: true },
      take: 5,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      results.remaining = await prisma.campaignRecipient.count({
        where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      });
      return NextResponse.json({ ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const contact = r.contact;
        const campaign = r.campaign;

        const sender = await pickNextSenderStrict({ batchLimit: campaign.batchLimit ?? 1 });
        if (!sender) { results.errors.push('No sender'); break; }

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
        });

        const recipientData = {
          name: contact.name || '',
          email: contact.email,
          company: contact.company || '',
          city: contact.city || '',
          phone: contact.phone || '',
        };

        const finalSubject = formatSubject(campaign.subject, recipientData);
        let html = renderTemplate(campaign.html, recipientData);

        const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: contact.email,
          subject: finalSubject,
          html,
          text: htmlToText(html),
          unsubscribeUrl: `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`,
        });

        const res = await gmail.users.messages.send({
          userId: 'me',
          requestBody: { raw: Buffer.from(raw).toString('base64url') },
        });

        await prisma.campaignRecipient.update({
          where: { id: r.id },
          data: { status: 'SENT', senderAccountId: sender.id, providerMessageId: res.data.id, sentAt: new Date() },
        });
        await prisma.campaign.update({
          where: { id: campaign.id },
          data: { sentCount: { increment: 1 } },
        });
        await markSenderUsed(sender.id);
        results.sent++;
      } catch (err: any) {
        results.failed++;
        results.errors.push(err?.message?.slice(0, 100));
      }
    }

    results.remaining = await prisma.campaignRecipient.count({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
    });
    return NextResponse.json(results);
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message, ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/tick/route.ts
echo "   ✅ Tick route — uses formatSubject"

# ═══════════════════════════════════════════
# 5. REWRITE LOCAL-SENDER.JS — same logic
# ═══════════════════════════════════════════
echo ""
echo "📝 [5/6] Rewriting local-sender.js..."

cat > local-sender.js <<'EOF'
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');
const http = require('http');

const prisma = new PrismaClient();
const POLL_MS = 3000;
const BATCH = 3;

const state = { startedAt: new Date(), totalSent: 0, totalFailed: 0 };

// ═══════════════════════════════════════════
// HEALTH SERVER
// ═══════════════════════════════════════════
http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      uptime: Math.floor((Date.now() - state.startedAt.getTime()) / 1000),
      totalSent: state.totalSent,
      totalFailed: state.totalFailed,
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
}).listen(3001, () => console.log('[health] :3001'));

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════
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

function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

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

function renderTemplate(t, data) {
  if (!t) return '';
  return t.replace(/\{\{\s*(\w+)(?:\s*\|\s*default\s*:\s*"([^"]*)")?\s*\}\}/g, (_, k, def) => {
    const v = data[k];
    return (v === undefined || v === null || v === '') ? (def ?? '') : String(v);
  });
}

// ═══════════════════════════════════════════
// SUBJECT FORMATTER — CONGRATULATIONS + LABEL
// ═══════════════════════════════════════════
function getDisplayLabel(contact) {
  const name = String(contact?.name || '').trim();
  if (name) return name;

  const company = String(contact?.company || '').trim();
  if (company) return company;

  const email = String(contact?.email || '').trim();
  if (!email) return 'Friend';

  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';

  return clean.split(/\s+/).filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
}

function formatSubject(template, contact) {
  if (!template) return '';
  const label = getDisplayLabel(contact);
  const subject = template.trim();

  // Rule 1: has variable
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }

  // Rule 2: starts with CONGRATULATIONS
  if (/^congratulations/i.test(subject)) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${label} — ${rest}`
      : `CONGRATULATIONS 🎉 ${label}`;
  }

  // Rule 3: prepend
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

// ═══════════════════════════════════════════
// SENDER PICK
// ═══════════════════════════════════════════
const TIERS = [
  { maxDay: 3, limit: 5 }, { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 }, { maxDay: 30, limit: 50 },
];
function effectiveLimit(s) {
  if (!s.warmupEnabled) return s.dailyLimit || 350;
  const t = TIERS.find(x => s.warmupDay <= x.maxDay);
  return t ? Math.min(t.limit, s.dailyLimit || 350) : (s.dailyLimit || 350);
}

async function pickSender(batchLimit) {
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });
  if (!senders.length) return null;

  for (const s of senders) {
    if (s.sentToday >= effectiveLimit(s)) continue;
    if (s.batchCount < batchLimit) return s;
  }

  await prisma.senderAccount.updateMany({
    where: { status: 'CONNECTED', isActive: true, refreshToken: { not: null } },
    data: { batchCount: 0 },
  });

  const fresh = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
  });

  for (const s of fresh) if (s.sentToday < effectiveLimit(s)) return s;
  return null;
}

// ═══════════════════════════════════════════
// SEND ONE
// ═══════════════════════════════════════════
async function sendViaGmail(sender, to, subject, html, text, unsubUrl) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
    to, subject, html, text, unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  try {
    if (res.data.id) {
      await gmail.users.messages.modify({
        userId: 'me', id: res.data.id,
        requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
      });
    }
  } catch {}

  return res.data.id;
}

async function processOne(r) {
  const campaign = await prisma.campaign.findUnique({ where: { id: r.campaignId } });
  if (!campaign || campaign.status !== 'RUNNING') return;

  const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    return;
  }

  await prisma.campaignRecipient.update({
    where: { id: r.id },
    data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
  });

  const sender = await pickSender(campaign.batchLimit ?? 1);
  if (!sender) {
    await prisma.campaignRecipient.update({
      where: { id: r.id }, data: { status: 'QUEUED' },
    });
    return;
  }

  const contact = r.contact;
  const recipientData = {
    name: contact.name || '',
    email: contact.email,
    company: contact.company || '',
    city: contact.city || '',
    phone: contact.phone || '',
  };

  const finalSubject = formatSubject(campaign.subject, recipientData);
  let html = renderTemplate(campaign.html, recipientData);

  const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
  html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;

  console.log(`📤 [${sender.email}] → ${contact.email} | Company: "${contact.company}" | Subject: "${finalSubject}"`);

  try {
    const providerMessageId = await sendViaGmail(
      sender, contact.email, finalSubject, html, htmlToText(html), unsubUrl
    );

    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId,
        sentAt: new Date(),
      },
    });
    await prisma.campaign.update({
      where: { id: campaign.id }, data: { sentCount: { increment: 1 } },
    });
    await prisma.senderAccount.update({
      where: { id: sender.id },
      data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
    });

    state.totalSent++;
    console.log(`   ✅ SENT`);
  } catch (err) {
    state.totalFailed++;
    const msg = err?.message || 'failed';
    await prisma.campaignRecipient.update({
      where: { id: r.id },
      data: {
        status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
        errorMessage: msg.slice(0, 200),
      },
    });
    console.log(`   ❌ ${msg.slice(0, 80)}`);
  }
}

let busy = false;
async function poll() {
  if (busy) return;
  busy = true;
  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: { status: 'QUEUED', campaign: { status: 'RUNNING' } },
      include: { contact: true },
      take: BATCH,
      orderBy: { queuedAt: 'asc' },
    });
    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued`);
      for (const r of recips) await processOne(r);
    }
  } catch (e) {
    console.error('Poll error:', e.message);
  } finally {
    busy = false;
  }
}

console.log('\n🚀 WORKER (with subject personalization)');
console.log('   Poll:', POLL_MS / 1000 + 's');
console.log('');

poll();
setInterval(poll, POLL_MS);

process.on('SIGTERM', async () => { await prisma.$disconnect(); process.exit(0); });
process.on('SIGINT', async () => { await prisma.$disconnect(); process.exit(0); });
EOF
sed -i 's/\r$//' local-sender.js
echo "   ✅ local-sender.js — uses formatSubject"

# ═══════════════════════════════════════════
# 6. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: subject personalization in ALL routes (bulk + process + tick + local)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ SUBJECT PERSONALIZATION FIXED EVERYWHERE"
echo "==============================================="
echo ""
echo "🎯 Kya fix hua:"
echo ""
echo "✓ lib/personalization.ts — clean formatSubject()"
echo "✓ /api/worker/bulk — uses formatSubject"
echo "✓ /api/worker/process — uses formatSubject"
echo "✓ /api/worker/tick — uses formatSubject"
echo "✓ local-sender.js — uses formatSubject"
echo ""
echo "📧 Ab subject aise banega:"
echo ""
echo "Contact: kaltagediya@gmail.com, Company: CertWinX"
echo "   Subject: CONGRATULATIONS 🎉 CertWinX"
echo ""
echo "Contact: rahul@acme.com, Name: Rahul, Company: Acme"
echo "   Subject: CONGRATULATIONS 🎉 Rahul"
echo ""
echo "Contact: no name/company, email: priya@startup.io"
echo "   Subject: CONGRATULATIONS 🎉 Priya"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "⚠️  IMPORTANT — Purane stuck emails:"
echo "   • Jo QUEUED hain → naye subject ke saath jayengi"
echo "   • Jo SENT ho chuki → wapas nahi bhejengi (already sent)"
echo "   • Test karne ke liye NAYA campaign banao"
echo "==============================================="