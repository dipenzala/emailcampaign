#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: GitHub Actions Workflow Failure"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. DELETE OLD BROKEN WORKFLOW
# ═══════════════════════════════════════════
echo "🗑️  [1/6] Removing old email-bot.yml..."

rm -f .github/workflows/email-bot.yml 2>/dev/null && echo "   ✅ Removed" || echo "   ℹ️  Not found"

# ═══════════════════════════════════════════
# 2. ROBUST BOT.PARALLEL (no Prisma at module level)
# ═══════════════════════════════════════════
echo ""
echo "🤖 [2/6] Rewriting bot-parallel.js (bulletproof)..."

mkdir -p scripts

cat > scripts/bot-parallel.js <<'EOF'
#!/usr/bin/env node
/**
 * PARALLEL BOT — bulletproof version
 * No Prisma import at top level (avoid startup crash)
 */

require('dotenv').config();

const BOT_ID = process.env.BOT_ID || `bot-${Math.random().toString(36).slice(2, 8)}`;
const BATCH_SIZE = parseInt(process.env.BOT_BATCH_SIZE || '20', 10);
const DELAY_MS = parseInt(process.env.BOT_DELAY_MS || '1200', 10);
const APP_URL = process.env.APP_URL || 'http://localhost:3000';

let prisma, google, crypto;

const state = { started: Date.now(), sent: 0, failed: 0, suppressed: 0, bounced: 0 };

// ═══════════════════════════════════════════
// LAZY LOAD MODULES
// ═══════════════════════════════════════════
async function loadModules() {
  console.log('[bot] Loading modules...');
  try {
    const prismaMod = await import('@prisma/client');
    prisma = new prismaMod.PrismaClient();
    console.log('[bot] ✅ Prisma client loaded');
  } catch (e) {
    console.error('[bot] ❌ Prisma failed:', e.message);
    throw e;
  }

  try {
    const g = await import('googleapis');
    google = g.google;
    console.log('[bot] ✅ Google APIs loaded');
  } catch (e) {
    console.error('[bot] ❌ Google APIs failed:', e.message);
    throw e;
  }

  crypto = await import('crypto');
}

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════
function decrypt(payload) {
  try {
    const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const data = buf.subarray(28);
    const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
    d.setAuthTag(tag);
    return Buffer.concat([d.update(data), d.final()]).toString('utf8');
  } catch { return null; }
}

function encrypt(plain) {
  const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', KEY, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
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

function getLabel(contact) {
  const name = String(contact?.name || '').trim();
  if (name) return name;
  const company = String(contact?.company || '').trim();
  if (company) return company;
  const email = String(contact?.email || '');
  if (!email) return 'Friend';
  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';
  return clean.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
}

function formatSubject(template, contact) {
  if (!template) return '';
  const label = getLabel(contact);
  const subject = template.trim();
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }
  if (/^congratulations/i.test(subject)) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest ? `CONGRATULATIONS 🎉 ${label} — ${rest}` : `CONGRATULATIONS 🎉 ${label}`;
  }
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

// ═══════════════════════════════════════════
// WARM-UP
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
// MAIN
// ═══════════════════════════════════════════
async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════');
  console.log(` 🤖 ${BOT_ID} STARTED`);
  console.log('═══════════════════════════════════════════');
  console.log(`  Batch size: ${BATCH_SIZE}`);
  console.log(`  Delay:      ${DELAY_MS}ms`);
  console.log(`  App URL:    ${APP_URL}`);
  console.log(`  DB:         ${(process.env.DATABASE_URL || '').slice(0, 50)}...`);
  console.log('');

  await loadModules();

  try {
    // ═══════════════════════════════════════════
    // PICK via API
    // ═══════════════════════════════════════════
    let pickData;
    try {
      const pickRes = await fetch(`${APP_URL}/api/bot/pick`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ botId: BOT_ID, batchSize: BATCH_SIZE }),
      });
      const text = await pickRes.text();
      try {
        pickData = JSON.parse(text);
      } catch {
        console.error('❌ API returned non-JSON:', text.slice(0, 200));
        process.exit(1);
      }
    } catch (e) {
      console.error('❌ Pick API failed:', e.message);
      process.exit(1);
    }

    if (!pickData.ok) {
      console.error('❌ Pick failed:', pickData.error);
      process.exit(1);
    }

    if (pickData.claimed === 0) {
      console.log('💤 No queued emails');
      process.exit(0);
    }

    console.log(`📬 Claimed ${pickData.claimed} unique emails`);
    console.log('');

    // ═══════════════════════════════════════════
    // SEND EACH
    // ═══════════════════════════════════════════
    for (const r of pickData.recipients) {
      try {
        // Suppression
        const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
        if (sup) {
          await fetch(`${APP_URL}/api/bot/mark-sent`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ recipientId: r.id, status: 'SUPPRESSED', error: sup.reason }),
          });
          state.suppressed++;
          continue;
        }

        const sender = await pickSender(r.campaign.batchLimit ?? 1);
        if (!sender) {
          await fetch(`${APP_URL}/api/bot/mark-sent`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ recipientId: r.id, status: 'QUEUED' }),
          });
          console.log('⏸️  No sender — stopping');
          break;
        }

        const data = {
          name: r.contact.name || '',
          email: r.contact.email,
          company: r.contact.company || '',
          city: r.contact.city || '',
          phone: r.contact.phone || '',
        };

        const finalSubject = formatSubject(r.campaign.subject, data);
        let html = renderTemplate(r.campaign.html, data);

        const pixel = `<img src="${APP_URL}/api/track/open/${r.id}" width="1" height="1" style="display:none" alt="" />`;
        html = /<\/body>/i.test(html) ? html.replace(/<\/body>/i, `${pixel}</body>`) : html + pixel;

        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        const unsubUrl = `${APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
        const raw = buildMime({
          from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
          to: r.contact.email,
          subject: finalSubject,
          html,
          text: htmlToText(html),
          unsubUrl,
        });

        const sendRes = await gmail.users.messages.send({
          userId: 'me',
          requestBody: { raw: Buffer.from(raw).toString('base64url') },
        });

        try {
          if (sendRes.data.id) {
            await gmail.users.messages.modify({
              userId: 'me',
              id: sendRes.data.id,
              requestBody: { addLabelIds: ['SENT'], removeLabelIds: ['INBOX', 'UNREAD'] },
            });
          }
        } catch {}

        if (access && refresh) {
          await prisma.senderAccount.update({
            where: { id: sender.id },
            data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
          }).catch(() => {});
        }

        await fetch(`${APP_URL}/api/bot/mark-sent`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipientId: r.id,
            senderId: sender.id,
            providerMessageId: sendRes.data.id,
            status: 'SENT',
          }),
        });

        state.sent++;
        console.log(`✅ [${sender.email}] → ${r.contact.email}`);

        if (DELAY_MS > 0) await new Promise(r => setTimeout(r, DELAY_MS));
      } catch (err) {
        const msg = err.message || 'unknown';
        const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid/i.test(msg);
        const isRateLimit = /rate|quota|429/i.test(msg);

        state.failed++;
        console.log(`❌ Failed: ${msg.slice(0, 100)}`);

        await fetch(`${APP_URL}/api/bot/mark-sent`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipientId: r.id,
            status: isBounce ? 'BOUNCED' : 'FAILED',
            error: msg.slice(0, 200),
          }),
        }).catch(() => {});

        if (isRateLimit) break;
      }
    }

    console.log('');
    console.log('═══════════════════════════════════════════');
    console.log(` 📊 ${BOT_ID} RESULTS`);
    console.log('═══════════════════════════════════════════');
    console.log(`  ✅ Sent:       ${state.sent}`);
    console.log(`  ❌ Failed:     ${state.failed}`);
    console.log(`  🚫 Suppressed: ${state.suppressed}`);
    console.log(`  ⏱️  Duration:   ${((Date.now() - state.started) / 1000).toFixed(1)}s`);
    console.log('═══════════════════════════════════════════');
  } catch (err) {
    console.error('❌ FATAL:', err.message);
    process.exit(1);
  } finally {
    if (prisma) await prisma.$disconnect().catch(() => {});
    process.exit(0);
  }
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
EOF
sed -i 's/\r$//' scripts/bot-parallel.js
chmod +x scripts/bot-parallel.js
echo "   ✅ scripts/bot-parallel.js (bulletproof)"

# ═══════════════════════════════════════════
# 3. ROBUST WORKFLOWS (better error handling)
# ═══════════════════════════════════════════
echo ""
echo "⚙️  [3/6] Rewriting workflows..."

mkdir -p .github/workflows

create_workflow() {
  local BOT_ID=$1
  local CRON=$2
  cat > ".github/workflows/bot-${BOT_ID}.yml" <<EOF
name: 🤖 Bot ${BOT_ID}

on:
  schedule:
    - cron: '${CRON}'
  workflow_dispatch:

jobs:
  send:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Cache node_modules
        uses: actions/cache@v4
        with:
          path: node_modules
          key: \${{ runner.os }}-node-\${{ hashFiles('package-lock.json') }}
          restore-keys: |
            \${{ runner.os }}-node-

      - name: Install dependencies (skip scripts)
        run: npm install --ignore-scripts --no-audit --no-fund

      - name: Generate Prisma client
        run: npx prisma generate
        env:
          DATABASE_URL: \${{ secrets.DATABASE_URL }}

      - name: Run Bot
        env:
          DATABASE_URL: \${{ secrets.DATABASE_URL }}
          REDIS_URL: \${{ secrets.REDIS_URL }}
          GOOGLE_CLIENT_ID: \${{ secrets.GOOGLE_CLIENT_ID }}
          GOOGLE_CLIENT_SECRET: \${{ secrets.GOOGLE_CLIENT_SECRET }}
          GOOGLE_REDIRECT_URI: \${{ secrets.GOOGLE_REDIRECT_URI }}
          TOKEN_ENCRYPTION_KEY: \${{ secrets.TOKEN_ENCRYPTION_KEY }}
          SESSION_SECRET: \${{ secrets.SESSION_SECRET }}
          APP_URL: \${{ secrets.APP_URL }}
          NODE_ENV: production
          BOT_ID: '${BOT_ID}'
          BOT_BATCH_SIZE: '20'
          BOT_DELAY_MS: '1200'
        run: node scripts/bot-parallel.js
EOF
  sed -i 's/\r$//' ".github/workflows/bot-${BOT_ID}.yml"
}

# 3 bots with different times
create_workflow "bot1" "*/5 * * * *"
create_workflow "bot2" "2-59/5 * * * *"
create_workflow "bot3" "4-59/5 * * * *"

echo "   ✅ 3 workflows created"
echo "      .github/workflows/bot-bot1.yml"
echo "      .github/workflows/bot-bot2.yml"
echo "      .github/workflows/bot-bot3.yml"

# ═══════════════════════════════════════════
# 4. FIX PACKAGE.JSON — bot:parallel script
# ═══════════════════════════════════════════
echo ""
echo "📦 [4/6] Updating package.json..."

node <<'NODEEOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts['bot:parallel'] = 'node scripts/bot-parallel.js';
pkg.scripts['bot'] = 'node scripts/bot.js';
// Add prisma to dependencies (needed for generate in workflow)
pkg.dependencies = pkg.dependencies || {};
if (!pkg.dependencies.prisma) pkg.dependencies.prisma = '^5.22.0';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('   ✅ package.json updated');
NODEEOF

# ═══════════════════════════════════════════
# 5. FIX ATOMIC PICK API — safety check
# ═══════════════════════════════════════════
echo ""
echo "🔒 [5/6] Verifying atomic pick API..."

if [ ! -f "app/api/bot/pick/route.ts" ]; then
  echo "   ⚠️  Atomic pick API missing — check previous script ran"
else
  echo "   ✅ Atomic pick API exists"
fi

# ═══════════════════════════════════════════
# 6. GIT PUSH
# ═══════════════════════════════════════════
echo ""
echo "🌿 [6/6] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: bulletproof workflows + lazy Prisma loading"

git push -u origin main 2>&1 | tail -10

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "🎯 Kya fix hua:"
echo "  ✓ Old email-bot.yml deleted"
echo "  ✓ bot-parallel.js — lazy Prisma load (no crash)"
echo "  ✓ 3 new workflows (bot-bot1/2/3)"
echo "  ✓ Better error handling + non-JSON responses"
echo "  ✓ Cache for node_modules (faster runs)"
echo ""
echo "⏱️  2-3 min me GitHub Actions update hoga"
echo ""
echo "📋 AGLE STEPS:"
echo ""
echo "1. GitHub Actions kholo:"
echo "   https://github.com/dipenzala/emailcampaign/actions"
echo ""
echo "2. Purane failed runs → 'Delete' nahi chahiye"
echo "   Naye runs automactically aayenge"
echo ""
echo "3. Manual test:"
echo "   Left side me 3 workflows dikhenge:"
echo "   • 🤖 Bot bot1"
echo "   • 🤖 Bot bot2"
echo "   • 🤖 Bot bot3"
echo ""
echo "   Kisi pe click → 'Run workflow' → 'Run workflow'"
echo ""
echo "4. Logs check karo:"
echo "   ✅ [bot] Loading modules..."
echo "   ✅ [bot] Prisma client loaded"
echo "   ✅ [bot] Google APIs loaded"
echo "   📬 Claimed 20 unique emails"
echo "   ✅ Sent X emails"
echo ""
echo "==============================================="