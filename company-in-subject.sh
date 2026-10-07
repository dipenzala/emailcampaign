#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🏢 COMPANY NAME IN SUBJECT"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. PERSONALIZATION LIB — Company-based
# ═══════════════════════════════════════════
echo "🎨 [1/5] Updating personalizer (company)..."

cat > lib/personalization.ts <<'EOF'
/**
 * Personalization engine for email subject + HTML.
 * Subject format: "CONGRATULATIONS 🎉 [Company Name]"
 */

/**
 * Render template string with data.
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
 * Extract company from email domain.
 * Fallback if company field is empty.
 *
 * Examples:
 *   rahul@acmecorp.com       → "Acmecorp"
 *   priya@tech-startup.io    → "Tech Startup"
 *   amit@mycompany.co.in     → "Mycompany"
 */
function companyFromEmail(email: string): string {
  if (!email) return 'Friend';
  const domain = email.split('@')[1] || '';
  if (!domain) return 'Friend';

  // Remove common TLDs
  const parts = domain.split('.');
  const name = parts[0] || '';

  // Skip generic providers
  const generic = ['gmail', 'yahoo', 'hotmail', 'outlook', 'live', 'icloud', 'aol', 'protonmail', 'zoho', 'yandex'];
  if (generic.includes(name.toLowerCase())) {
    return 'Friend';
  }

  // Clean: remove hyphens, underscores; capitalize
  const clean = name.replace(/[._\-]+/g, ' ').trim();
  const pretty = clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');

  return pretty || 'Friend';
}

/**
 * ⭐ Get best display name — COMPANY first, then email fallback.
 */
export function getRecipientCompany(data: Record<string, any>): string {
  const company = String(data.company || '').trim();
  if (company) return company;
  return companyFromEmail(String(data.email || ''));
}

/**
 * ⭐ Format subject with COMPANY NAME + CONGRATULATIONS prefix.
 *
 * Rules:
 *  1. If subject already has {{company}} → render it
 *  2. If subject starts with "CONGRATULATIONS" → append company name only
 *  3. Else → prepend "CONGRATULATIONS 🎉 [Company] — " before original subject
 *
 * Examples:
 *   Template: "Congratulations", Company: "Acme Corp"
 *     → "CONGRATULATIONS 🎉 Acme Corp"
 *
 *   Template: "Big Sale Today", Company: "Startup IO"
 *     → "CONGRATULATIONS 🎉 Startup IO — Big Sale Today"
 */
export function formatSubject(subjectTemplate: string, data: Record<string, any>): string {
  if (!subjectTemplate) return '';
  const company = getRecipientCompany(data);
  const subject = subjectTemplate.trim();

  // Rule 1: If already has {{company}} → render
  if (/\{\{\s*company/.test(subject)) {
    return renderTemplate(subject, { ...data, company });
  }

  // Rule 2: Starts with CONGRATULATIONS
  const upperSubject = subject.toUpperCase();
  if (upperSubject.startsWith('CONGRATULATIONS')) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${company} — ${rest}`
      : `CONGRATULATIONS 🎉 ${company}`;
  }

  // Rule 3: Prepend
  return `CONGRATULATIONS 🎉 ${company} — ${subject}`;
}

/**
 * Full personalization helper.
 */
export function personalize(data: Record<string, any>, subjectTemplate: string, htmlTemplate: string) {
  return {
    subject: formatSubject(subjectTemplate, data),
    html: renderTemplate(htmlTemplate, data),
  };
}
EOF
sed -i 's/\r$//' lib/personalization.ts
echo "   ✅ lib/personalization.ts (company-based)"

# ═══════════════════════════════════════════
# 2. UPDATE BULK ROUTE — use company
# ═══════════════════════════════════════════
echo ""
echo "📝 [2/5] Updating bulk route..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/worker/bulk/route.ts';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Bulk route not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Replace name usage with company in formatSubject call
if (c.includes('formatSubject')) {
  c = c.replace(
    /formatSubject\(\s*campaign\.subject,\s*\{[\s\S]*?\}\s*\)/,
    `formatSubject(campaign.subject, {
              company: contact.company ?? '',
              name: contact.name ?? '',
              email: contact.email,
            })`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Bulk route uses company');
NODEEOF

# ═══════════════════════════════════════════
# 3. UPDATE LOCAL-SENDER — company
# ═══════════════════════════════════════════
echo ""
echo "📝 [3/5] Updating local-sender..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'local-sender.js';
if (!fs.existsSync(f)) {
  console.log('   ℹ️  local-sender.js not found — skip');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Replace the getRecipientName + formatSubject block with company version
c = c.replace(
  /\/\/ ⭐ Format subject with client name \+ CONGRATULATIONS prefix[\s\S]*?\n\}/,
  `// ⭐ Format subject with COMPANY name + CONGRATULATIONS prefix
function getRecipientCompany(data) {
  const company = String(data.company || '').trim();
  if (company) return company;
  const email = String(data.email || '');
  if (!email) return 'Friend';
  const domain = email.split('@')[1] || '';
  if (!domain) return 'Friend';
  const parts = domain.split('.');
  const name = parts[0] || '';
  const generic = ['gmail', 'yahoo', 'hotmail', 'outlook', 'live', 'icloud', 'aol', 'protonmail', 'zoho', 'yandex'];
  if (generic.includes(name.toLowerCase())) return 'Friend';
  const clean = name.replace(/[._\\-]+/g, ' ').trim();
  const pretty = clean.split(/\\s+/).filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
  return pretty || 'Friend';
}

function formatSubject(template, data) {
  if (!template) return '';
  const company = getRecipientCompany(data);
  const subject = template.trim();

  if (/\\{\\{\\s*company/.test(subject)) {
    return renderTemplate(subject, { ...data, company });
  }

  const upper = subject.toUpperCase();
  if (upper.startsWith('CONGRATULATIONS')) {
    const rest = subject.replace(/^congratulations[\\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? \`CONGRATULATIONS 🎉 \${company} — \${rest}\`
      : \`CONGRATULATIONS 🎉 \${company}\`;
  }

  return \`CONGRATULATIONS 🎉 \${company} — \${subject}\`;
}`
);

// Update the call site — use company
c = c.replace(
  /const formattedSubject = formatSubject\(subject, \{[\s\S]*?\}\);/,
  `const formattedSubject = formatSubject(subject, {
      company: contact?.company ?? '',
      name: contact?.name ?? '',
      email: to,
    });`
);

fs.writeFileSync(f, c);
console.log('   ✅ local-sender.js updated');
NODEEOF

# ═══════════════════════════════════════════
# 4. UPDATE CAMPAIGN FORM — company preview
# ═══════════════════════════════════════════
echo ""
echo "🎨 [4/5] Updating campaign form..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Campaign page not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Update preview — replace {Client Name} with {Company Name}
c = c.replace(
  /\{Client Name\}/g,
  '{Company Name}'
);

c = c.replace(
  /Type "<b>\{\{name\}\}<\/b>" to place name elsewhere\./g,
  'Type "<b>{{company}}</b>" to place company elsewhere.'
);

c = c.replace(
  /Auto-uses "CONGRATULATIONS 🎉 \[Name\]" otherwise\./g,
  'Auto-uses "CONGRATULATIONS 🎉 [Company]" otherwise.'
);

fs.writeFileSync(f, c);
console.log('   ✅ Campaign form preview updated');
NODEEOF

# ═══════════════════════════════════════════
# 5. Git push
# ═══════════════════════════════════════════
echo ""
echo "🌿 [5/5] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: subject uses COMPANY name — CONGRATULATIONS 🎉 [Company]"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ COMPANY NAME IN SUBJECT DEPLOYED"
echo "==============================================="
echo ""
echo "🎯 Ab kya hoga:"
echo ""
echo "Rule 1: Subject has {{company}}"
echo "   Input:  'Offer for {{company}}'"
echo "   Output: 'Offer for Acme Corp'"
echo ""
echo "Rule 2: Subject starts with CONGRATULATIONS"
echo "   Input:  'Congratulations'"
echo "   Output: 'CONGRATULATIONS 🎉 Acme Corp'"
echo ""
echo "Rule 3: Any other subject"
echo "   Input:  'Big Sale Today'"
echo "   Output: 'CONGRATULATIONS 🎉 Acme Corp — Big Sale Today'"
echo ""
echo "📊 Company name kahan se aayega:"
echo "   1. Excel me 'Company' column ho → wahi use hoga"
echo "   2. Warna email domain se extract:"
echo "      rahul@acmecorp.com → 'Acmecorp'"
echo "   3. Gmail use kiya to → 'Friend'"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo ""
echo "Test:"
echo "   /campaigns/new → Subject: 'Congratulations'"
echo "   Excel: rahul@acme.com, Company: Acme Corp"
echo "   Email subject: CONGRATULATIONS 🎉 Acme Corp"
echo "==============================================="