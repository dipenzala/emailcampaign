#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🏢 FIX: Company Column (Simple)"
echo "==============================================="

cd ~/OneDrive/Desktop/EML/emailcampaign

# Find the table header file
FILE="app/campaigns/new/page.tsx"
[ -f "$FILE" ] || { echo "❌ File not found"; exit 1; }

echo "📝 Adding Company column..."

# Use Python for reliable text manipulation (no regex escape issues)
python3 <<'PYEOF'
import re

f = "app/campaigns/new/page.tsx"
with open(f, "r", encoding="utf-8") as fp:
    c = fp.read()

# ─── Add Company header ───
# Find: <th>Name</th>
# Add after: <th>Company</th>
if ">Company</th>" not in c:
    # Simple string replace
    header_pattern = "<th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Name</th>"
    if header_pattern in c:
        c = c.replace(
            header_pattern,
            header_pattern + "\n                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Company</th>"
        )
        print("   ✅ Header added")
    else:
        # Try alternative (older format)
        alt = ">Name</th>"
        if alt in c and ">Company</th>" not in c:
            c = c.replace(alt, alt + "\n                      <th style={{ textAlign: 'left', padding: 10, color: 'var(--fg-muted)', fontWeight: 700 }}>Company</th>", 1)
            print("   ✅ Header added (alt)")
        else:
            print("   ⚠️  Name header not found")

# ─── Add Company cell ───
# Find: {c.name || '—'}
# Add after: {c.company || '—'}
cell_pattern = """<td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.name || '—'}</td>"""
if cell_pattern in c and "{c.company || '—'}" not in c:
    c = c.replace(
        cell_pattern,
        cell_pattern + """\n                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}</td>""",
        1
    )
    print("   ✅ Cell added")
else:
    # Try simpler
    if "{c.name || '—'}" in c and "{c.company || '—'}" not in c:
        c = c.replace(
            "{c.name || '—'}",
            "{c.name || '—'}</td>\n                        <td style={{ padding: 10, color: 'var(--fg-muted)' }}>{c.company || '—'}",
            1
        )
        print("   ✅ Cell added (alt)")

with open(f, "w", encoding="utf-8") as fp:
    fp.write(c)

# ─── Improve upload API ───
api_f = "app/api/contacts/upload/route.ts"
if __import__('os').path.exists(api_f):
    with open(api_f, "r", encoding="utf-8") as fp:
        api = fp.read()

    # Just add more company header variants
    if "'company'" in api and "'business'" not in api:
        api = api.replace(
            "'company', 'organization', 'org'",
            "'company', 'company name', 'organization', 'organisation', 'org', 'business', 'firm'"
        )
        with open(api_f, "w", encoding="utf-8") as fp:
            fp.write(api)
        print("   ✅ Upload API improved")

print("\n✅ Done")
PYEOF

echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"
git add -A
git diff --cached --quiet || git commit -m "Fix: add Company column to contacts table"
git push 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ DONE"
echo "==============================================="