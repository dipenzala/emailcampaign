#!/usr/bin/env bash
set -e

echo "==============================================="
echo " ⏰ TIME-SCHEDULED BULK CAMPAIGN"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. PRISMA SCHEMA — add scheduling fields
# ═══════════════════════════════════════════
echo "📝 [1/7] Adding scheduling fields to Campaign model..."

if ! grep -q "scheduleDurationMinutes" prisma/schema.prisma; then
  node <<'NODEEOF'
const fs = require('fs');
let s = fs.readFileSync('prisma/schema.prisma', 'utf8');

// Add fields to Campaign model
s = s.replace(
  /model Campaign \{([\s\S]*?)\n\}/,
  (match, body) => {
    const fields = `
  // ═══ Scheduling fields (new) ═══
  campaignType             String   @default("normal")
  scheduleStartHour        Int      @default(10)
  scheduleStartMinute      Int      @default(0)
  scheduleDurationMinutes  Int      @default(120)
  lastActiveDate           DateTime?
  nextRunAt                DateTime?
`;
    return `model Campaign {${body}${fields}\n}`;
  }
);

fs.writeFileSync('prisma/schema.prisma', s);
console.log('   ✅ Schedule fields added');
NODEEOF
else
  echo "   ✅ Schedule fields already exist"
fi

# ═══════════════════════════════════════════
# 2. CREATE SCHEDULED CAMPAIGN API
# ═══════════════════════════════════════════
echo ""
echo "🔌 [2/7] Creating scheduled campaign API..."

mkdir -p app/api/campaigns/scheduled

cat > app/api/campaigns/scheduled/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const Schema = z.object({
  name: z.string().min(1),
  subject: z.string().min(1),
  html: z.string().min(20),
  scheduleStartHour: z.number().int().min(0).max(23),
  scheduleStartMinute: z.number().int().min(0).max(59),
  scheduleDurationMinutes: z.number().int().min(30).max(480),
});

// CREATE scheduled campaign
export async function POST(req: Request) {
  try {
    const parsed = Schema.safeParse(await req.json());
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
    }

    const {
      name, subject, html,
      scheduleStartHour, scheduleStartMinute, scheduleDurationMinutes,
    } = parsed.data;

    const campaign = await prisma.campaign.create({
      data: {
        name,
        subject,
        html,
        status: 'DRAFT',
        campaignType: 'scheduled',
        scheduleStartHour,
        scheduleStartMinute,
        scheduleDurationMinutes,
        batchLimit: 1,
      },
    });

    return NextResponse.json({ ok: true, id: campaign.id });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// LIST scheduled campaigns
export async function GET() {
  try {
    const list = await prisma.campaign.findMany({
      where: { campaignType: 'scheduled' },
      orderBy: { createdAt: 'desc' },
    });
    return NextResponse.json(list);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/scheduled/route.ts
echo "   ✅ POST/GET /api/campaigns/scheduled"

# ═══════════════════════════════════════════
# 3. CHUNK UPLOAD API — for 3 lakh emails
# ═══════════════════════════════════════════
echo ""
echo "📦 [3/7] Creating chunk upload API..."

mkdir -p app/api/campaigns/scheduled/upload-chunk

cat > app/api/campaigns/scheduled/upload-chunk/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

/**
 * Chunked upload endpoint.
 * Frontend parses Excel → splits into chunks of 5000 rows → sends each chunk here.
 * Server inserts bulk with createMany + skipDuplicates.
 */
export async function POST(req: Request) {
  try {
    const { campaignId, rows, finalize } = await req.json();

    if (!campaignId) {
      return NextResponse.json({ error: 'campaignId required' }, { status: 400 });
    }

    // Verify campaign
    const campaign = await prisma.campaign.findUnique({
      where: { id: campaignId },
    });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }
    if (campaign.campaignType !== 'scheduled') {
      return NextResponse.json({ error: 'Not a scheduled campaign' }, { status: 400 });
    }

    let inserted = 0;
    let duplicates = 0;
    let invalid = 0;
    let suppressed = 0;

    if (rows && Array.isArray(rows) && rows.length > 0) {
      // Fetch suppression list once
      const emails = rows
        .map((r: any) => String(r.email || '').trim().toLowerCase())
        .filter(Boolean);

      const suppressionSet = new Set<string>();
      if (emails.length > 0) {
        const sup = await prisma.suppressionList.findMany({
          where: { email: { in: emails } },
          select: { email: true },
        });
        sup.forEach(s => suppressionSet.add(s.email));
      }

      // Filter rows
      const validRows: any[] = [];
      const seenInChunk = new Set<string>();

      for (const row of rows) {
        const email = String(row.email || '').trim().toLowerCase();
        if (!email) { invalid++; continue; }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { invalid++; continue; }
        if (seenInChunk.has(email)) { duplicates++; continue; }
        seenInChunk.add(email);
        if (suppressionSet.has(email)) { suppressed++; continue; }

        validRows.push({
          email,
          company: String(row.company || '').trim().slice(0, 200),
        });
      }

      // Bulk upsert contacts
      try {
        await prisma.contact.createMany({
          data: validRows.map(r => ({
            email: r.email,
            company: r.company || null,
          })),
          skipDuplicates: true,
        });
      } catch (e: any) {
        console.warn('[chunk] contact createMany warning:', e.message);
      }

      // Fetch contacts to get IDs
      const contacts = await prisma.contact.findMany({
        where: { email: { in: validRows.map(r => r.email) } },
        select: { id: true, email: true },
      });
      const contactMap = new Map(contacts.map(c => [c.email, c.id]));

      // Insert campaign recipients
      const recipients = validRows
        .map(r => ({
          campaignId,
          contactId: contactMap.get(r.email) || '',
          status: 'QUEUED',
        }))
        .filter(r => r.contactId);

      // Insert in batches of 1000
      const BATCH = 1000;
      for (let i = 0; i < recipients.length; i += BATCH) {
        const slice = recipients.slice(i, i + BATCH);
        try {
          const res = await prisma.campaignRecipient.createMany({
            data: slice,
            skipDuplicates: true,
          });
          inserted += res.count;
        } catch (e: any) {
          console.warn('[chunk] recipient insert warning:', e.message);
        }
      }
    }

    // Finalize — update campaign total count
    if (finalize) {
      const totalCount = await prisma.campaignRecipient.count({
        where: { campaignId },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { totalCount },
      });
      return NextResponse.json({
        ok: true,
        finalized: true,
        inserted,
        duplicates,
        invalid,
        suppressed,
        totalCount,
      });
    }

    return NextResponse.json({
      ok: true,
      inserted,
      duplicates,
      invalid,
      suppressed,
    });
  } catch (err: any) {
    console.error('[chunk] error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/campaigns/scheduled/upload-chunk/route.ts
echo "   ✅ Chunk upload API"

# ═══════════════════════════════════════════
# 4. SCHEDULED WORKER — checks time window
# ═══════════════════════════════════════════
echo ""
echo "⏰ [4/7] Creating scheduled worker..."

mkdir -p app/api/worker/scheduled

cat > app/api/worker/scheduled/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';
import { autoResetIfNewDay } from '@/lib/daily-reset';

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
  const now = new Date();
  const results: any = {
    ok: true,
    now: now.toISOString(),
    localTime: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
    processed: 0, sent: 0, failed: 0, skipped: 0,
    activeCampaigns: [] as string[],
    inactiveCampaigns: [] as string[],
    elapsed: 0,
  };

  try {
    // ⚡ Daily reset
    try {
      await autoResetIfNewDay();
    } catch {}

    // Get all RUNNING scheduled campaigns
    const scheduledCampaigns = await prisma.campaign.findMany({
      where: {
        campaignType: 'scheduled',
        status: 'RUNNING',
      },
    });

    if (scheduledCampaigns.length === 0) {
      results.message = 'No active scheduled campaigns';
      results.elapsed = Date.now() - t0;
      return j(results);
    }

    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    for (const campaign of scheduledCampaigns) {
      const startMinutes = campaign.scheduleStartHour * 60 + campaign.scheduleStartMinute;
      const endMinutes = startMinutes + campaign.scheduleDurationMinutes;

      // Check if in active window
      const isActive = currentMinutes >= startMinutes && currentMinutes < endMinutes;

      if (!isActive) {
        results.inactiveCampaigns.push(campaign.name);
        continue;
      }

      results.activeCampaigns.push(campaign.name);

      // Update lastActiveDate
      await prisma.campaign.update({
        where: { id: campaign.id },
        data: { lastActiveDate: now },
      });

      // Fetch queued emails for this campaign (small batch)
      const recips = await prisma.campaignRecipient.findMany({
        where: {
          campaignId: campaign.id,
          status: 'QUEUED',
        },
        include: { contact: true },
        take: 20,
        orderBy: { queuedAt: 'asc' },
      });

      if (recips.length === 0) {
        // Check if campaign is complete
        const remaining = await prisma.campaignRecipient.count({
          where: { campaignId: campaign.id, status: { in: ['QUEUED', 'PROCESSING'] } },
        });
        if (remaining === 0) {
          await prisma.campaign.update({
            where: { id: campaign.id },
            data: { status: 'COMPLETED', completedAt: new Date() },
          });
          console.log(`🎉 [scheduled] Campaign "${campaign.name}" COMPLETED`);
        }
        continue;
      }

      // Process each
      for (const r of recips) {
        results.processed++;
        try {
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
            results.skipped++;
            continue;
          }

          // Pick sender
          const sender = await pickNextSenderStrict({ batchLimit: 1 });
          if (!sender) {
            results.skipped++;
            break;
          }

          // Mark processing
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 },
          });

          // Build email
          const recipientData = {
            name: contact.name || '',
            email: contact.email,
            company: contact.company || '',
            city: contact.city || '',
            phone: contact.phone || '',
          };

          const finalSubject = formatSubject(campaign.subject, recipientData);
          let html = renderTemplate(campaign.html, recipientData);

          // Pixel
          const pixel = `<img src="${process.env.APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
          html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

          // Send via Gmail
          const access = sender.accessToken ? decrypt(sender.accessToken) : '';
          const refresh = decrypt(sender.refreshToken);
          const c = oauthClient();
          c.setCredentials({ access_token: access, refresh_token: refresh });
          const gmail = google.gmail({ version: 'v1', auth: c });

          const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
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

          // Update DB
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
          console.log(`[scheduled] ✅ ${contact.email} (${contact.company || 'no company'})`);
        } catch (err: any) {
          const msg = err?.message ?? 'failed';
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
          } else {
            await prisma.campaignRecipient.update({
              where: { id: r.id },
              data: {
                status: r.attemptCount < 3 ? 'QUEUED' : 'FAILED',
                errorMessage: msg.slice(0, 200),
              },
            }).catch(() => {});
          }
          results.failed++;
        }

        // Time check — if we're near end of window, stop
        const nowCheck = new Date();
        const checkMinutes = nowCheck.getHours() * 60 + nowCheck.getMinutes();
        if (checkMinutes >= endMinutes) {
          console.log(`[scheduled] Window ended for "${campaign.name}"`);
          break;
        }
      }
    }

    results.elapsed = Date.now() - t0;
    return j(results);
  } catch (err: any) {
    console.error('[scheduled] FATAL:', err);
    return j({ ok: false, error: err?.message, ...results }, 500);
  }
}
EOF
sed -i 's/\r$//' app/api/worker/scheduled/route.ts
echo "   ✅ Scheduled worker"

# ═══════════════════════════════════════════
# 5. UI — Scheduled Campaign Create Page
# ═══════════════════════════════════════════
echo ""
echo "🎨 [5/7] Creating scheduled campaign UI..."

mkdir -p app/campaigns/scheduled/new

cat > app/campaigns/scheduled/new/page.tsx <<'EOF'
'use client';
import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from '@/components/Toast';

type Row = { email: string; company: string };

export default function ScheduledCampaignNew() {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);

  const [step, setStep] = useState(1);
  const [name, setName] = useState('Scheduled ' + new Date().toISOString().slice(0, 10));
  const [subject, setSubject] = useState('CONGRATULATIONS 🎉');
  const [html, setHtml] = useState('<!DOCTYPE html>\n<html>\n<body>\n<h1>Hello {{name}}</h1>\n<p>Update for {{company}}.</p>\n<p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>\n</body>\n</html>');

  const [startHour, setStartHour] = useState(10);
  const [startMinute, setStartMinute] = useState(0);
  const [durationMinutes, setDurationMinutes] = useState(120); // 2 hours

  const [rows, setRows] = useState<Row[]>([]);
  const [fileStats, setFileStats] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [campaignId, setCampaignId] = useState<string | null>(null);

  const CHUNK_SIZE = 5000;

  // ═══════════════════════════════════════════
  // Excel parsing (client-side)
  // ═══════════════════════════════════════════
  const handleFile = async (f: File) => {
    setBusy(true);
    setUploadProgress(0);
    try {
      const XLSX = await import('xlsx');
      const buf = await f.arrayBuffer();
      const wb = XLSX.read(buf, { type: 'array' });
      const sheet = wb.Sheets[wb.SheetNames[0]];
      const raw: any[] = XLSX.utils.sheet_to_json(sheet, { defval: '', raw: false });

      if (!raw.length) throw new Error('File has no rows');

      // Find email + company columns
      const headers = Object.keys(raw[0] || {});
      const norm = (s: string) => String(s).toLowerCase().replace(/[_\-\s]/g, '');
      const emailKey = headers.find(h => ['email', 'emailaddress', 'mail'].includes(norm(h))) ||
                       headers.find(h => raw.slice(0, 5).some(r => String(r[h] || '').includes('@')));
      const companyKey = headers.find(h => /company|organi|business|firm/.test(norm(h))) ||
                         headers.filter(h => h !== emailKey)[0];

      if (!emailKey) throw new Error('No email column found');

      const parsed: Row[] = [];
      const seen = new Set<string>();
      let invalid = 0, duplicates = 0;

      for (const r of raw) {
        const email = String(r[emailKey] || '').trim().toLowerCase();
        if (!email) { invalid++; continue; }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { invalid++; continue; }
        if (seen.has(email)) { duplicates++; continue; }
        seen.add(email);
        parsed.push({
          email,
          company: companyKey ? String(r[companyKey] || '').trim() : '',
        });
      }

      setRows(parsed);
      setFileStats({
        total: raw.length,
        valid: parsed.length,
        invalid,
        duplicates,
      });
      toast(`✅ ${parsed.length} valid emails loaded`, 'success');
    } catch (e: any) {
      toast('❌ ' + e.message, 'error');
    }
    setBusy(false);
  };

  // ═══════════════════════════════════════════
  // Create campaign + chunk upload
  // ═══════════════════════════════════════════
  const launch = async () => {
    if (!rows.length) { toast('Add emails first', 'error'); return; }
    if (!subject.trim() || !html.trim()) { toast('Subject + HTML required', 'error'); return; }

    setBusy(true);
    setUploadProgress(0);

    try {
      // Create campaign
      const r = await fetch('/api/campaigns/scheduled', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name, subject, html,
          scheduleStartHour: startHour,
          scheduleStartMinute: startMinute,
          scheduleDurationMinutes: durationMinutes,
        }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      const newCampaignId = j.id;
      setCampaignId(newCampaignId);

      // Upload in chunks
      const totalChunks = Math.ceil(rows.length / CHUNK_SIZE);
      for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
        const slice = rows.slice(i, i + CHUNK_SIZE);
        const isFinal = (i + CHUNK_SIZE) >= rows.length;

        const cr = await fetch('/api/campaigns/scheduled/upload-chunk', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            campaignId: newCampaignId,
            rows: slice,
            finalize: isFinal,
          }),
        });
        const cj = await cr.json();
        if (!cj.ok) throw new Error(cj.error);

        const chunkIdx = Math.floor(i / CHUNK_SIZE) + 1;
        setUploadProgress(Math.round((chunkIdx / totalChunks) * 100));
      }

      // Set campaign to RUNNING
      await fetch(`/api/campaigns/${newCampaignId}/start`, { method: 'POST' });

      toast('🎉 Scheduled campaign created!', 'success');
      setTimeout(() => router.push('/campaigns/scheduled'), 1500);
    } catch (e: any) {
      toast('❌ ' + e.message, 'error');
      setBusy(false);
    }
  };

  // Compute end time display
  const endTime = (() => {
    const total = startHour * 60 + startMinute + durationMinutes;
    return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
  })();

  return (
    <div className="space-y-5 max-w-4xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">⏰ Scheduled Campaign</h1>
          <p className="text-sm text-slate-400 mt-1">Daily time-window bulk sender</p>
        </div>
        <Link href="/campaigns/scheduled" className="btn btn-ghost text-sm">← Back</Link>
      </div>

      {/* STEP 1 — Schedule */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 1 — Set Daily Schedule</h2>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Campaign Name</label>
            <input className="input" value={name} onChange={e => setName(e.target.value)} />
          </div>
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Start Time</label>
            <div className="flex gap-2">
              <select
                className="input"
                value={startHour}
                onChange={e => setStartHour(parseInt(e.target.value))}
              >
                {Array.from({ length: 24 }, (_, i) => (
                  <option key={i} value={i}>{String(i).padStart(2, '0')}</option>
                ))}
              </select>
              <select
                className="input"
                value={startMinute}
                onChange={e => setStartMinute(parseInt(e.target.value))}
              >
                {[0, 15, 30, 45].map(m => (
                  <option key={m} value={m}>{String(m).padStart(2, '0')}</option>
                ))}
              </select>
            </div>
          </div>
        </div>

        <div className="mt-4">
          <label className="text-xs text-slate-400 font-semibold mb-2 block">Daily Active Duration</label>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
            {[60, 120, 180, 240].map(min => (
              <button
                key={min}
                onClick={() => setDurationMinutes(min)}
                className={'btn text-sm ' + (durationMinutes === min ? 'btn-primary' : 'btn-ghost')}
              >
                {min / 60} hour{min > 60 ? 's' : ''}
              </button>
            ))}
          </div>
          <div className="mt-3 text-sm text-slate-500">
            ⏰ Active window: <b>{String(startHour).padStart(2, '0')}:{String(startMinute).padStart(2, '0')}</b> → <b>{endTime}</b> (daily)
          </div>
        </div>
      </div>

      {/* STEP 2 — Emails */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 2 — Upload Bulk Emails (Excel / CSV)</h2>

        <input
          ref={fileRef}
          type="file"
          accept=".xlsx,.xls,.csv"
          onChange={e => e.target.files?.[0] && handleFile(e.target.files[0])}
          disabled={busy}
          className="input"
        />

        <div className="text-xs text-slate-500 mt-2">
          Excel format: 2 columns — <b>Company Name</b> + <b>Email</b> (3 lakh+ rows supported)
        </div>

        {fileStats && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
            <Stat label="TOTAL ROWS" value={fileStats.total} />
            <Stat label="VALID" value={fileStats.valid} color="#10b981" />
            <Stat label="INVALID" value={fileStats.invalid} color="#ef4444" />
            <Stat label="DUPLICATES" value={fileStats.duplicates} color="#f59e0b" />
          </div>
        )}

        {uploadProgress > 0 && uploadProgress < 100 && (
          <div className="mt-4">
            <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
              <div className="h-full bg-violet-500 transition-all" style={{ width: uploadProgress + '%' }} />
            </div>
            <div className="text-xs text-slate-500 mt-1">Uploading: {uploadProgress}%</div>
          </div>
        )}
      </div>

      {/* STEP 3 — Subject + HTML */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Step 3 — Email Content</h2>

        <div className="space-y-3">
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">Subject</label>
            <input className="input" value={subject} onChange={e => setSubject(e.target.value)} />
            <div className="text-xs text-slate-500 mt-2 p-2 rounded bg-violet-50 border border-violet-200">
              Preview: <b>CONGRATULATIONS 🎉 {`{Company Name}`}</b>
            </div>
          </div>
          <div>
            <label className="text-xs text-slate-400 font-semibold mb-1 block">HTML Body</label>
            <textarea
              className="input font-mono text-xs"
              rows={12}
              value={html}
              onChange={e => setHtml(e.target.value)}
            />
          </div>
        </div>
      </div>

      {/* LAUNCH */}
      <div className="card">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <div className="text-sm font-semibold">Ready to launch?</div>
            <div className="text-xs text-slate-500 mt-1">
              {rows.length} emails · {durationMinutes / 60}h window daily
            </div>
          </div>
          <button
            onClick={launch}
            disabled={busy || !rows.length || !subject.trim()}
            className="btn btn-primary"
            style={{ padding: '14px 32px', fontSize: 15 }}
          >
            {busy ? `⏳ Uploading ${uploadProgress}%` : `🚀 LAUNCH SCHEDULED CAMPAIGN`}
          </button>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, color = 'var(--fg)' }: { label: string; value: number; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 12 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 800, color, marginTop: 4 }}>{value.toLocaleString()}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/campaigns/scheduled/new/page.tsx
echo "   ✅ Scheduled create page"

# ═══════════════════════════════════════════
# 6. UI — Scheduled Campaigns List
# ═══════════════════════════════════════════
echo ""
echo "🎨 [6/7] Creating scheduled campaigns list..."

mkdir -p app/campaigns/scheduled

cat > app/campaigns/scheduled/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function ScheduledCampaignsPage() {
  const [list, setList] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const r = await fetch('/api/campaigns/scheduled');
      const j = await r.json();
      setList(Array.isArray(j) ? j : []);
    } catch {}
    setLoading(false);
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 5000);
    return () => clearInterval(iv);
  }, []);

  const now = new Date();
  const currentMin = now.getHours() * 60 + now.getMinutes();

  const isActiveNow = (c: any) => {
    const start = c.scheduleStartHour * 60 + c.scheduleStartMinute;
    const end = start + c.scheduleDurationMinutes;
    return currentMin >= start && currentMin < end;
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">⏰ Scheduled Campaigns</h1>
          <p className="text-sm text-slate-400 mt-1">Daily time-window bulk sends</p>
        </div>
        <Link href="/campaigns/scheduled/new" className="btn btn-primary">+ New Scheduled</Link>
      </div>

      {/* Current time banner */}
      <div className="card" style={{ background: 'rgba(139,92,246,0.06)', borderColor: 'rgba(139,92,246,0.25)' }}>
        <div className="text-sm">
          Current server time: <b>{String(now.getHours()).padStart(2, '0')}:{String(now.getMinutes()).padStart(2, '0')}</b>
        </div>
      </div>

      {loading ? (
        <div className="card text-center py-8 text-slate-500">Loading...</div>
      ) : list.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-4xl mb-3">⏰</div>
          <p className="text-slate-400 mb-4">No scheduled campaigns yet</p>
          <Link href="/campaigns/scheduled/new" className="btn btn-primary">+ Create First</Link>
        </div>
      ) : (
        <div className="space-y-3">
          {list.map(c => {
            const active = isActiveNow(c) && c.status === 'RUNNING';
            const start = `${String(c.scheduleStartHour).padStart(2, '0')}:${String(c.scheduleStartMinute).padStart(2, '0')}`;
            const endMin = c.scheduleStartHour * 60 + c.scheduleStartMinute + c.scheduleDurationMinutes;
            const end = `${String(Math.floor(endMin / 60) % 24).padStart(2, '0')}:${String(endMin % 60).padStart(2, '0')}`;
            const sent = c.sentCount || 0;
            const total = c.totalCount || 0;
            const progress = total > 0 ? (sent / total) * 100 : 0;

            return (
              <div key={c.id} className="card" style={{
                borderColor: active ? 'rgba(16,185,129,0.4)' : undefined,
                borderWidth: active ? 2 : 1,
              }}>
                <div className="flex items-start justify-between gap-3 flex-wrap mb-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-base">{c.name}</span>
                      <span className={`text-xs px-2 py-1 rounded font-bold ${
                        active ? 'bg-emerald-100 text-emerald-700 animate-pulse' :
                        c.status === 'COMPLETED' ? 'bg-slate-100 text-slate-600' :
                        c.status === 'RUNNING' ? 'bg-blue-100 text-blue-700' :
                        'bg-amber-100 text-amber-700'
                      }`}>
                        {active ? '🟢 ACTIVE NOW' : c.status}
                      </span>
                    </div>
                    <div className="text-xs text-slate-500 mt-1 truncate">{c.subject}</div>
                  </div>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                  <Info label="TIME WINDOW" value={`${start} → ${end}`} />
                  <Info label="DURATION" value={`${c.scheduleDurationMinutes / 60}h`} />
                  <Info label="TOTAL" value={total.toLocaleString()} />
                  <Info label="SENT" value={sent.toLocaleString()} color="#10b981" />
                </div>

                <div className="mb-3">
                  <div className="flex justify-between text-xs text-slate-500 mb-1">
                    <span>Progress</span>
                    <span>{progress.toFixed(1)}%</span>
                  </div>
                  <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
                    <div
                      className="h-full transition-all"
                      style={{
                        width: progress + '%',
                        background: progress >= 100 ? '#10b981' : 'linear-gradient(90deg,#8b5cf6,#ec4899)',
                      }}
                    />
                  </div>
                </div>

                <div className="flex gap-2 flex-wrap">
                  <Link href={`/campaigns/${c.id}`} className="btn btn-ghost text-xs">📊 Details</Link>
                  <span className="text-xs text-slate-400 self-center">
                    Last active: {c.lastActiveDate ? new Date(c.lastActiveDate).toLocaleString() : 'never'}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function Info({ label, value, color = 'var(--fg)' }: { label: string; value: string; color?: string }) {
  return (
    <div style={{ background: 'var(--bg-subtle)', borderRadius: 10, padding: 10 }}>
      <div style={{ fontSize: 9, textTransform: 'uppercase', color: 'var(--fg-dim)', fontWeight: 700, letterSpacing: '0.1em' }}>{label}</div>
      <div style={{ fontSize: 14, fontWeight: 700, color, marginTop: 3 }}>{value}</div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/campaigns/scheduled/page.tsx
echo "   ✅ Scheduled list page"

# ═══════════════════════════════════════════
# 7. SIDEBAR — Add link
# ═══════════════════════════════════════════
echo ""
echo "🎨 [7/7] Adding sidebar link + git push..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'components/Sidebar.tsx';
if (!fs.existsSync(f)) process.exit(0);
let c = fs.readFileSync(f, 'utf8');

if (!c.includes('/campaigns/scheduled')) {
  c = c.replace(
    /\{ href: '\/campaigns\/new', label: 'New Campaign', icon: '✉️' \},/,
    `{ href: '/campaigns/new', label: 'New Campaign', icon: '✉️' },
      { href: '/campaigns/scheduled', label: 'Scheduled Bulk', icon: '⏰' },
      { href: '/campaigns/scheduled/new', label: 'New Scheduled', icon: '📅' },`
  );
  fs.writeFileSync(f, c);
  console.log('   ✅ Sidebar updated');
}
NODEEOF

git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: scheduled bulk campaign (daily time-window, 3L+ emails)"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ SCHEDULED CAMPAIGN DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Kya mila (alag module):"
echo ""
echo "⏰ SCHEDULED CAMPAIGNS (/campaigns/scheduled):"
echo "   • Daily time-window (1h, 2h, 3h, 4h choose)"
echo "   • Start time picker (HH:MM)"
echo "   • 3 lakh+ emails per campaign"
echo "   • Auto-resume next day"
echo "   • Chunk upload (no size limit)"
echo "   • Company name in subject"
echo ""
echo "🚀 CREATE (/campaigns/scheduled/new):"
echo "   Step 1: Set time window"
echo "   Step 2: Upload Excel (Company + Email)"
echo "   Step 3: Subject + HTML"
echo "   Launch → Uploads in chunks → RUNNING"
echo ""
echo "🔄 WORKER:"
echo "   • Checks current time every run"
echo "   • Active window me → emails bheje"
echo "   • Outside window → skip (no sending)"
echo "   • Next day same time → resume"
echo "   • Complete hone tak daily active"
echo ""
echo "📊 DASHBOARD:"
echo "   • Green 'ACTIVE NOW' badge when running"
echo "   • Progress bar (X/Y sent)"
echo "   • Time window display"
echo "   • Last active timestamp"
echo ""
echo "⚠️  IMPORTANT:"
echo "   • Existing campaigns abhi bhi kaam karenge"
echo "   • Ye alag module hai"
echo "   • Sidebar me 'Scheduled Bulk' section"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "📱 Test:"
echo "   https://emailcampaign-ten.vercel.app/campaigns/scheduled"
echo "   https://emailcampaign-ten.vercel.app/campaigns/scheduled/new"
echo ""
echo "⚠️  UptimeRobot setup zaroori hai:"
echo "   URL: https://emailcampaign-ten.vercel.app/api/worker/scheduled"
echo "   Interval: 5 minutes"
echo "==============================================="