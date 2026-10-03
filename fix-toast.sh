#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🔧 FIX: Create missing components"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

mkdir -p components

# ==========================================
# 1. Toast component
# ==========================================
echo "📝 Creating components/Toast.tsx..."

cat > components/Toast.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';

type ToastItem = { id: string; message: string; type: 'success' | 'error' | 'info' };

let addToastExternal: ((t: ToastItem) => void) | null = null;

export function toast(message: string, type: 'success' | 'error' | 'info' = 'info') {
  if (addToastExternal) {
    addToastExternal({ id: Math.random().toString(36).slice(2), message, type });
  }
}

export default function ToastContainer() {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  useEffect(() => {
    addToastExternal = (t) => {
      setToasts(prev => [...prev, t]);
      setTimeout(() => {
        setToasts(prev => prev.filter(x => x.id !== t.id));
      }, 4000);
    };
    return () => { addToastExternal = null; };
  }, []);

  return (
    <div className="toast-container">
      {toasts.map(t => (
        <div key={t.id} className="toast">
          <span>{t.type === 'success' ? '✅' : t.type === 'error' ? '❌' : 'ℹ️'}</span>
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  );
}
EOF
sed -i 's/\r$//' components/Toast.tsx
echo "   ✅"

# ==========================================
# 2. Verify other components
# ==========================================
echo ""
echo "🔎 Checking other components..."

for f in AppShell Sidebar Topbar; do
  if [ -f "components/$f.tsx" ]; then
    echo "   ✅ components/$f.tsx"
  else
    echo "   ❌ MISSING components/$f.tsx"
  fi
done

# ==========================================
# 3. Verify tsconfig paths
# ==========================================
echo ""
echo "🔎 Checking tsconfig.json..."

if grep -q '"@/\*"' tsconfig.json; then
  echo "   ✅ @/* path alias configured"
else
  echo "   ⚠️  Adding @/* path alias..."
  node -e '
const fs = require("fs");
const ts = JSON.parse(fs.readFileSync("tsconfig.json", "utf8"));
ts.compilerOptions = ts.compilerOptions || {};
ts.compilerOptions.baseUrl = ".";
ts.compilerOptions.paths = ts.compilerOptions.paths || {};
ts.compilerOptions.paths["@/*"] = ["./*"];
fs.writeFileSync("tsconfig.json", JSON.stringify(ts, null, 2));
console.log("   ✅ Added");
'
fi

# ==========================================
# 4. Rebuild verification (local)
# ==========================================
echo ""
echo "🔎 Verifying app/layout.tsx imports..."
if grep -q "components/Toast" app/layout.tsx; then
  echo "   ✅ app/layout.tsx imports Toast"
fi
if grep -q "components/AppShell" app/layout.tsx; then
  echo "   ✅ app/layout.tsx imports AppShell"
fi

# ==========================================
# 5. Git push
# ==========================================
echo ""
echo "🌿 Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Fix: create missing components/Toast.tsx"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ FIXED"
echo "==============================================="
echo ""
echo "Files created:"
echo "   ✓ components/Toast.tsx"
echo ""
echo "🎯 Ab Vercel auto-rebuild hoga 2-3 min me"
echo ""
echo "Check karo:"
echo "   https://vercel.com/certwinx/emailcampaign-ten/deployments"
echo ""
echo "Agar 'Ready' (green) dikha to app chalega!"
echo "==============================================="