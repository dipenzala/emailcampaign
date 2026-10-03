#!/usr/bin/env bash

echo "==============================================="
echo " 🔧 Fix: Encryption Key + Sender Reconnect"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. Fix TOKEN_ENCRYPTION_KEY in .env
# ==========================================
echo "🔐 Step 1: Checking TOKEN_ENCRYPTION_KEY..."

CORRECT_KEY="f371f9f48cc14371b941f26f23afe6d37462b143b48187457a2ea0eb642ade02"

if [ ! -f ".env" ]; then
  echo "❌ .env nahi mila"
  exit 1
fi

CURRENT_KEY=$(grep "^TOKEN_ENCRYPTION_KEY=" .env | cut -d'=' -f2 | tr -d '"')

if [ "$CURRENT_KEY" == "$CORRECT_KEY" ]; then
  echo "   ✅ Key already correct"
else
  echo "   ⚠️  Key mismatch!"
  echo "   Current: ${CURRENT_KEY:0:30}..."
  echo "   Fixing to Vercel's key..."
  sed -i "s|^TOKEN_ENCRYPTION_KEY=.*|TOKEN_ENCRYPTION_KEY=\"$CORRECT_KEY\"|" .env
  echo "   ✅ Fixed"
fi

# Also check SESSION_SECRET
CORRECT_SESSION="8a5880c2c17e072ec23a79da604e6f3ac1e60e88302d01bdd1844d80fe6ad62aad2f1cadc66ec63df1405f9e1188ae3a"
CURRENT_SESSION=$(grep "^SESSION_SECRET=" .env | cut -d'=' -f2 | tr -d '"')

if [ "$CURRENT_SESSION" != "$CORRECT_SESSION" ]; then
  echo "   ⚠️  SESSION_SECRET mismatch — fixing"
  sed -i "s|^SESSION_SECRET=.*|SESSION_SECRET=\"$CORRECT_SESSION\"|" .env
fi

echo ""

# ==========================================
# 2. Delete corrupted sender tokens
# ==========================================
echo "🗑️  Step 2: Clearing corrupted sender tokens..."

node -e '
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  
  const senders = await p.senderAccount.findMany();
  console.log("   Found " + senders.length + " senders");
  
  for (const s of senders) {
    await p.senderAccount.update({
      where: { id: s.id },
      data: {
        status: "DISCONNECTED",
        accessToken: null,
        refreshToken: null,
        tokenExpiry: null,
      },
    });
    console.log("   🔒 Cleared: " + s.email);
  }
  
  // Reset failed recipients back to QUEUED for retry
  const reset = await p.campaignRecipient.updateMany({
    where: { status: "FAILED" },
    data: { status: "QUEUED", attemptCount: 0, errorMessage: null, errorCode: null },
  });
  console.log("");
  console.log("   🔄 Reset " + reset.count + " FAILED recipients → QUEUED");
  
  // Reset PROCESSING back to QUEUED
  const reset2 = await p.campaignRecipient.updateMany({
    where: { status: "PROCESSING" },
    data: { status: "QUEUED", attemptCount: 0 },
  });
  console.log("   🔄 Reset " + reset2.count + " PROCESSING recipients → QUEUED");
  
  await p.$disconnect();
})().catch(e => console.error("❌ DB:", e.message));
'

echo ""

# ==========================================
# 3. Verify
# ==========================================
echo "🔎 Step 3: Verification"
echo ""

if grep -q "$CORRECT_KEY" .env; then
  echo "   ✅ TOKEN_ENCRYPTION_KEY correct"
else
  echo "   ❌ Key still wrong"
fi

echo ""
echo "==============================================="
echo " ✅ CLEANUP DONE"
echo "==============================================="
echo ""
echo "🎯 AB YE KARO:"
echo ""
echo "1. Browser me kholo:"
echo "   https://emailcampaign-ten.vercel.app/senders"
echo ""
echo "2. DONO Gmail accounts ko RECONNECT karo:"
echo "   - Purane senders DELETE karo (agar option ho)"
echo "   - Naya email daalo: dipenzala1999@gmail.com"
echo "   - 'Connect Google' click karo"
echo "   - Allow permissions"
echo "   - Repeat for: startupcertwinx1@gmail.com"
echo ""
echo "3. Phir local sender chalao:"
echo "   bash local-sender.sh"
echo ""
echo "⚠️  IMPORTANT: Google OAuth screen pe 'Allow' karte waqt"
echo "   'Send email on your behalf' permission ALLOW karo"
echo "==============================================="