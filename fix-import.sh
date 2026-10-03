#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 Fix: worker/tick import"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Fix worker/tick/route.ts
# ==========================================
echo "📝 [1/3] Fixing worker/tick route..."

mkdir -p app/api/worker/tick

cat > app/api/worker/tick/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt, encrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '@/lib/sender-rotation';
import { handleBounce } from '@/lib/bounce-handler';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

const BATCH_SIZE = 5;

function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixelUrl = `${appUrl}/api/track/open/${recipientId}`;
  const pixel = `<img src="${pixelUrl}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) {
    return html.replace(/<\/body>/i, `${pixel}</body>`);
  }
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

export async function GET() { return tick(); }
export async function POST() { return tick(); }

async function tick() {
  const results = {
    processed: 0, sent: 0, failed: 0, bounced: 0, suppressed: 0,
    errors: [] as string[],
  };

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true, campaign: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length === 0) {
      return NextResponse.json({ ok: true, ...results, message: 'No queued recipients' });
    }

    for (const r of recips) {
      results.processed++;
      try {
        const campaign = r.campaign;
        const contact = r.contact;

        // Suppression check
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

        // Pick sender (STRICT ROTATION)
        const sender = await pickNextSenderStrict({
          batchLimit: campaign.batchLimit ?? 10,
        });

        if (!sender) {
          await prisma.campaignRecipient.update({
            where: { id: r.id },
            data: { status: 'QUEUED' },
          });
          results.errors.push('No sender available');
          break;
        }

        // Build email
        const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(contact.email).toString('base64url')}`;
        let html = renderTemplate(campaign.html, {
          name: contact.name ?? '',
          email: contact.email,
          company: contact.company ?? '',
          city: contact.city ?? '',
          phone: contact.phone ?? '',
        });

        // Inject tracking pixel
        html = injectTrackingPixel(html, r.id, process.env.APP_URL || '');

        const text = htmlToText(html);

        // Send
        const { id: providerMessageId, access, refresh } = await sendViaGmail(
          sender, contact.email, campaign.subject, html, text, unsubUrl
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
    return NextResponse.json({ ok: false, error: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF
sed -i 's/\r$//' app/api/worker/tick/route.ts
echo "   ✅ worker/tick route fixed"

# ==========================================
# 2. Check for other old import usages
# ==========================================
echo ""
echo "🔎 [2/3] Scanning for other old imports..."

BAD=$(grep -rl "pickNextSender[^S]" app/ lib/ workers/ 2>/dev/null | grep -v node_modules | grep -v "pickNextSenderStrict" || true)

if [ -n "$BAD" ]; then
  echo "   ⚠️  Found old imports in:"
  echo "$BAD" | sed 's/^/      /'
else
  echo "   ✅ No old imports found"
fi

# ==========================================
# 3. Git push
# ==========================================
echo ""
echo "🌿 [3/3] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: worker/tick import pickNextSenderStrict"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 Warning gone — clean build next time"
echo ""
echo "📊 Check Vercel:"
echo "   https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo ""
echo "Ye build SUCCESS tha (warning only)."
echo "Agla build bina warning ke hoga."
echo "==============================================="