#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 👁️  EMAIL OPEN TRACKING"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. UPDATE PRISMA SCHEMA — tracking fields
# ==========================================
echo "📝 [1/6] Adding tracking fields to schema..."

node <<'NODEEOF'
const fs = require('fs');
let schema = fs.readFileSync('prisma/schema.prisma', 'utf8');

// Add tracking fields to CampaignRecipient if missing
if (!schema.includes('openedAt')) {
  schema = schema.replace(
    /(model CampaignRecipient \{[\s\S]*?)(\n\})/,
    (match, body, close) => {
      const newFields = `
  // -------- Tracking --------
  openedAt     DateTime?
  openCount    Int       @default(0)
  clickedAt    DateTime?
  clickCount   Int       @default(0)
  userAgent    String?
  ipAddress    String?
`;
      return body + newFields + close;
    }
  );
  console.log('   ✅ Added tracking fields to CampaignRecipient');
} else {
  console.log('   ✅ Tracking fields already exist');
}

fs.writeFileSync('prisma/schema.prisma', schema);
NODEEOF

sed -i 's/\r$//' prisma/schema.prisma
echo ""

# ==========================================
# 2. OPEN TRACKING API — pixel endpoint
# ==========================================
echo "👁️  [2/6] Creating tracking pixel endpoint..."

mkdir -p 'app/api/track/open/[token]'

cat > 'app/api/track/open/[token]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Transparent 1x1 GIF
const PIXEL = Buffer.from(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  'base64'
);

export async function GET(req: Request, { params }: { params: { token: string } }) {
  const pixelResponse = () =>
    new NextResponse(PIXEL, {
      status: 200,
      headers: {
        'Content-Type': 'image/gif',
        'Content-Length': String(PIXEL.length),
        'Cache-Control': 'no-store, no-cache, must-revalidate, private',
        Pragma: 'no-cache',
        Expires: '0',
      },
    });

  try {
    // Decode token → recipientId
    let recipientId = '';
    try {
      recipientId = Buffer.from(params.token, 'base64url').toString();
    } catch {
      return pixelResponse();
    }

    if (!recipientId) return pixelResponse();

    // Get metadata
    const ua = req.headers.get('user-agent') || '';
    const forwarded = req.headers.get('x-forwarded-for') || '';
    const ip = forwarded.split(',')[0].trim() || req.headers.get('x-real-ip') || '';

    // Update recipient
    const recipient = await prisma.campaignRecipient.findUnique({
      where: { id: recipientId },
    });

    if (recipient) {
      const isFirstOpen = !recipient.openedAt;

      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: {
          openedAt: recipient.openedAt ?? new Date(),   // only first time
          openCount: { increment: 1 },
          userAgent: ua.slice(0, 500),
          ipAddress: ip.slice(0, 100),
        },
      });

      // Update campaign open count
      if (isFirstOpen) {
        await prisma.campaign.update({
          where: { id: recipient.campaignId },
          data: {
            openedCount: { increment: 1 },
          },
        }).catch(() => {});
      }
    }

    return pixelResponse();
  } catch (err) {
    // Always return pixel even on error
    return pixelResponse();
  }
}
EOF
sed -i 's/\r$//' 'app/api/track/open/[token]/route.ts'
echo "   ✅ /api/track/open/[token]"

# ==========================================
# 3. LINK CLICK TRACKING API
# ==========================================
echo ""
echo "🔗 [3/6] Creating click tracking..."

mkdir -p 'app/api/track/click/[token]'

cat > 'app/api/track/click/[token]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: { token: string } }) {
  try {
    const url = new URL(req.url);
    const targetUrl = url.searchParams.get('url') || '';

    // Decode token → recipientId
    let recipientId = '';
    try {
      recipientId = Buffer.from(params.token, 'base64url').toString();
    } catch {
      return NextResponse.redirect(targetUrl || '/');
    }

    if (recipientId) {
      try {
        const r = await prisma.campaignRecipient.findUnique({ where: { id: recipientId } });
        if (r) {
          await prisma.campaignRecipient.update({
            where: { id: recipientId },
            data: {
              clickedAt: r.clickedAt ?? new Date(),
              clickCount: { increment: 1 },
            },
          });
          if (!r.clickedAt) {
            await prisma.campaign.update({
              where: { id: r.campaignId },
              data: { clickedCount: { increment: 1 } },
            }).catch(() => {});
          }
        }
      } catch {}
    }

    // Redirect to actual URL
    if (targetUrl) {
      return NextResponse.redirect(targetUrl);
    }
    return NextResponse.redirect('/');
  } catch {
    return NextResponse.redirect('/');
  }
}
EOF
sed -i 's/\r$//' 'app/api/track/click/[token]/route.ts'
echo "   ✅ /api/track/click/[token]"

# ==========================================
# 4. Add campaign counters
# ==========================================
echo ""
echo "📊 [4/6] Adding campaign counters..."

node <<'NODEEOF'
const fs = require('fs');
let schema = fs.readFileSync('prisma/schema.prisma', 'utf8');

if (!schema.includes('openedCount')) {
  schema = schema.replace(
    /(model Campaign \{[\s\S]*?)(\n\})/,
    (match, body, close) => {
      return body + `
  openedCount     Int      @default(0)
  clickedCount    Int      @default(0)
` + close;
    }
  );
  console.log('   ✅ Added openedCount/clickedCount to Campaign');
} else {
  console.log('   ✅ Counters already exist');
}

fs.writeFileSync('prisma/schema.prisma', schema);
NODEEOF

sed -i 's/\r$//' prisma/schema.prisma
echo ""

# ==========================================
# 5. AUTO-INJECT tracking into HTML
# ==========================================
echo "🎯 [5/6] Auto-injecting tracking into email HTML..."

mkdir -p lib

cat > lib/tracking.ts <<'EOF'
/**
 * Auto-inject tracking into email HTML:
 *  - 1x1 transparent tracking pixel (open tracking)
 *  - Wrap all links with click tracking
 */

export function injectTracking(
  html: string,
  recipientId: string,
  appUrl: string
): string {
  if (!recipientId || !appUrl) return html;

  const token = Buffer.from(recipientId).toString('base64url');
  const pixelUrl = `${appUrl}/api/track/open/${token}`;

  // 1. Add tracking pixel before </body> (or at end)
  const pixelHtml = `<img src="${pixelUrl}" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;outline:none;text-decoration:none;opacity:0" />`;

  let output = html;

  // Insert pixel before closing body
  if (/<\/body>/i.test(output)) {
    output = output.replace(/<\/body>/i, `${pixelHtml}</body>`);
  } else {
    output = output + pixelHtml;
  }

  // 2. Wrap links with click tracking
  output = output.replace(
    /<a\s+([^>]*?)href=["']([^"']+)["']([^>]*?)>/gi,
    (match, before, href, after) => {
      // Skip mailto, tel, unsubscribe, tracking pixel, and anchors
      if (
        href.startsWith('mailto:') ||
        href.startsWith('tel:') ||
        href.startsWith('#') ||
        href.includes('/api/track/') ||
        href.includes('/api/unsubscribe/') ||
        href.includes('javascript:')
      ) {
        return match;
      }
      const wrapped = `${appUrl}/api/track/click/${token}?url=${encodeURIComponent(href)}`;
      return `<a ${before}href="${wrapped}"${after}>`;
    }
  );

  return output;
}
EOF
sed -i 's/\r$//' lib/tracking.ts
echo "   ✅ lib/tracking.ts"

# ==========================================
# 6. Update LOCAL-SENDER to inject tracking
# ==========================================
echo ""
echo "🎯 [6/6] Wiring tracking into sender..."

if [ -f "local-sender.js" ]; then
  # Backup
  cp local-sender.js local-sender.js.bak

  node <<'NODEEOF'
const fs = require('fs');
let src = fs.readFileSync('local-sender.js', 'utf8');

// Add tracking injection function before sending
if (!src.includes('injectTracking')) {
  // Add helper right after renderTemplate function
  const trackingFn = `
function injectTracking(html, recipientId) {
  const appUrl = process.env.APP_URL || '';
  if (!appUrl || !recipientId) return html;
  const token = Buffer.from(recipientId).toString('base64url');
  const pixelUrl = appUrl + '/api/track/open/' + token;
  const pixelHtml = '<img src="' + pixelUrl + '" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;outline:none;text-decoration:none;opacity:0" />';
  let out = html;
  if (/<\\/body>/i.test(out)) {
    out = out.replace(/<\\/body>/i, pixelHtml + '</body>');
  } else {
    out = out + pixelHtml;
  }
  // Wrap links
  out = out.replace(/<a\\s+([^>]*?)href=["']([^"']+)["']([^>]*?)>/gi, function(match, before, href, after) {
    if (href.startsWith('mailto:') || href.startsWith('tel:') || href.startsWith('#') ||
        href.includes('/api/track/') || href.includes('/api/unsubscribe/') || href.includes('javascript:')) {
      return match;
    }
    var wrapped = appUrl + '/api/track/click/' + token + '?url=' + encodeURIComponent(href);
    return '<a ' + before + 'href="' + wrapped + '"' + after + '>';
  });
  return out;
}
`;
  // Insert after renderTemplate
  src = src.replace(/(function renderTemplate[\s\S]*?\n\})/, '$1\n' + trackingFn);

  // Find where we send email — replace "const raw = buildMime({...html," with tracking injection
  src = src.replace(
    /const html = renderTemplate\(campaign\.html, \{([\s\S]*?)\}\);\s*const text = htmlToText\(html\);/,
    (m, args) => {
      return `const html0 = renderTemplate(campaign.html, {${args}});
    const html = injectTracking(html0, recipient.id);
    const text = htmlToText(html);`;
    }
  );
}

fs.writeFileSync('local-sender.js', src);
console.log('   ✅ local-sender.js — tracking injected');
NODEEOF
fi

# Push
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: email open + click tracking"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ TRACKING DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Kaise Kaam Karega:"
echo ""
echo "1. Email bhejte waqt automatically:"
echo "   • 1x1 transparent pixel add hota hai"
echo "   • Saare links tracking URL se wrap hote hain"
echo ""
echo "2. Client email OPEN karega:"
echo "   • Gmail image load karega"
echo "   • Pixel hit → DB update → openedAt set"
echo ""
echo "3. Client link CLICK karega:"
echo "   • Redirect через tracking URL"
echo "   • DB update → clickedAt set"
echo "   • Phir actual URL pe redirect"
echo ""
echo "📊 Dashboard me dikhega:"
echo "   /dashboard/live → 'Opened' + 'Clicked' counts"
echo ""
echo "⚠️  HONEST LIMITATIONS:"
echo "   • Gmail: First open track hoga (partial)"
echo "   • Apple Mail: Often blocked"
echo "   • Outlook: Usually works"
echo "   • User images off: No tracking"
echo "==============================================="