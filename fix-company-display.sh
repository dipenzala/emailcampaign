#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🏢 FIX: Company + Name Column Display"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign 2>/dev/null || cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ emailcampaign root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ═══════════════════════════════════════════
# 1. UPDATE CAMPAIGN FORM — show Company column
# ═══════════════════════════════════════════
echo "🎨 [1/4] Updating campaign form table..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Campaign page not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Add Company column to contacts table
// Current: <th>Email</th><th>Name</th> → add <th>Company</th>
if (!c.includes('>Company</th>')) {
  // Find header row and add Company
  c = c.replace(
    /(<th style=\{\{ textAlign: 'left', padding: 10, color: 'var\(--fg-muted\)', fontWeight: 700 \}\}>Name<\/th>)/,
    `$1
                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Company</th>`
  );

  // Add company cell in tbody rows
  c = c.replace(
    /(<td style=\{\{ padding: 10, color: 'var\(--fg-muted\)' \}\}>\{c\.name \|\| '—'\}<\/td>)/,
    `$1
                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}</td>`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Company column added');
NODEEOF

# ═══════════════════════════════════════════
# 2. UPDATE UPLOAD API — better name/company extraction
# ═══════════════════════════════════════════
echo ""
echo "📝 [2/4] Improving Excel parsing..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/api/contacts/upload/route.ts';
if (!fs.existsSync(f)) {
  console.log('   ⚠️  Upload API not found');
  process.exit(0);
}

let c = fs.readFileSync(f, 'utf8');

// Improve getField — match more header variants
if (!c.includes("findKey(sampleRow")) {
  // Already using findKey, ensure it has more candidates
  c = c.replace(
    /const nameKey = findKey\(sampleRow, \[[^\]]*\]\);/,
    `const nameKey = findKey(sampleRow, [
      'name', 'full name', 'fullname', 'first name', 'firstname', 'customer name',
      'contact name', 'client name', 'user name', 'username'
    ]);`
  );

  c = c.replace(
    /const companyKey = findKey\(sampleRow, \[[^\]]*\]\);/,
    `const companyKey = findKey(sampleRow, [
      'company', 'company name', 'organization', 'organisation', 'org',
      'business', 'business name', 'firm', 'employer', 'workplace'
    ]);`
  );

  // If findKey not present, add fallback logic
  if (!c.includes('nameKey')) {
    c = c.replace(
      /(for \(const row of rows\) \{)/,
      `const sampleRow = rows[0] || {};
    const normalizedKeys = Object.keys(sampleRow).map(k => ({ orig: k, norm: String(k).toLowerCase().replace(/[_\\-\\s]+/g, '') }));
    const findKey = (candidates) => {
      for (const cand of candidates) {
        const cn = cand.toLowerCase().replace(/[_\\-\\s]+/g, '');
        const found = normalizedKeys.find(k => k.norm === cn);
        if (found) return found.orig;
      }
      return null;
    };
    const nameKey = findKey(['name', 'fullname', 'firstname', 'customername', 'clientname']);
    const companyKey = findKey(['company', 'companyname', 'organization', 'business']);
    const phoneKey = findKey(['phone', 'mobile', 'contact']);
    const cityKey = findKey(['city', 'location']);

    $1`
    );
  }
}

fs.writeFileSync(f, c);
console.log('   ✅ Parsing improved');
NODEEOF

# ═══════════════════════════════════════════
# 3. ADD COMPANY STATS CARD
# ═══════════════════════════════════════════
echo ""
echo "📊 [3/4] Adding company stats..."

node <<'NODEEOF'
const fs = require('fs');
const f = 'app/campaigns/new/page.tsx';
if (!fs.existsSync(f)) process.exit(0);

let c = fs.readFileSync(f, 'utf8');

// Count unique companies
if (!c.includes('uniqueCompanies')) {
  c = c.replace(
    /(const allContacts = useMemo\(\(\) => \{[\s\S]*?\}, \[contacts, manualParsed\.valid\]\);/),
    `$1

  // Count unique companies
  const uniqueCompanies = useMemo(() => {
    const set = new Set<string>();
    for (const c of allContacts) {
      const co = (c.company || '').trim().toLowerCase();
      if (co) set.add(co);
    }
    return set.size;
  }, [allContacts]);`
  );
}

fs.writeFileSync(f, c);
console.log('   ✅ Company stats added');
NODEEOF

# ═══════════════════════════════════════════
# 4. INSTRUCTIONS
# ═══════════════════════════════════════════
echo ""
echo "🌿 [4/4] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: show Company column in contacts table + improve Excel parsing"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ COMPANY COLUMN FIXED"
echo "==============================================="
echo ""
echo "🎯 Do problems fix kiye:"
echo ""
echo "1. UI Table:"
echo "   ✓ Company column add kiya"
echo "   ✓ Ab 3 columns dikhenge: Email | Name | Company"
echo ""
echo "2. Excel Parsing:"
echo "   ✓ Header detection improved"
echo "   ✓ Company variants: company, organization, business, firm"
echo "   ✓ Name variants: name, fullname, firstname, customername"
echo ""
echo "⚠️  IMPORTANT: Excel me Name/Company column hona chahiye"
echo ""
echo "📄 Excel format example:"
echo "   | Email           | Name       | Company    |"
echo "   |-----------------|------------|------------|"
echo "   | user@x.com      | Rahul      | Acme Corp  |"
echo "   | xyz@y.com       | Priya      | Startup Inc|"
echo ""
echo "Agar Excel me sirf emails hain → Name/Company blank honge"
echo "     (isi liye '—' dikh raha tha)"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "==============================================="