#!/usr/bin/env bash
set -e

# ================================================
#  🚀 EmailCampaign — Deploy Script
#  GitHub: https://github.com/dipenzala/emailcampaign.git
# ================================================

REPO_URL="https://github.com/dipenzala/emailcampaign.git"
REPO_NAME="emailcampaign"
VERCEL_APP_NAME="emailcampaign"

echo "==================================================="
echo " 🚀 EmailCampaign — Deploy"
echo "==================================================="

# ---------- 1. Locate project ----------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if [ ! -f "package.json" ]; then
  echo "❌ package.json nahi mila. Pehle setup.sh chalao."
  echo "   Ya is script ko project root me rakho."
  exit 1
fi

PROJECT_DIR="$(pwd)"
echo "📁 Project: $PROJECT_DIR"

# ---------- 2. CRLF fix (Windows safety) ----------
echo ""
echo "🔧 Line endings fix kar raha hoon..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅ Done"

# ---------- 3. .gitignore ----------
if [ ! -f ".gitignore" ] || ! grep -q "node_modules" .gitignore 2>/dev/null; then
  echo ""
  echo "📝 Creating .gitignore..."
  cat > .gitignore <<'EOF'
node_modules/
.next/
out/
build/
dist/
.env
.env.local
.env*.local
.env.production
*.db
*.log
npm-debug.log*
.vscode/
.idea/
*.swp
.DS_Store
Thumbs.db
.vercel
coverage/
*.tsbuildinfo
next-env.d.ts
EOF
  echo "✅ .gitignore ready"
else
  echo "✅ .gitignore already present"
fi

# ---------- 4. Ensure .env is NOT tracked ----------
if [ -f ".env" ]; then
  if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo "⚠️  .env git me tracked tha — untrack kar raha hoon"
    git rm --cached .env 2>/dev/null || true
  fi
  echo "🔒 .env locally safe hai (git me nahi jayega)"
fi

# ---------- 5. Git init / remote ----------
echo ""
echo "🌿 Git setup..."
if [ ! -d ".git" ]; then
  git init
  git branch -M main
  echo "✅ git init"
else
  echo "✅ git already initialized"
fi

# Set remote (update if needed)
if git remote get-url origin >/dev/null 2>&1; then
  CURRENT=$(git remote get-url origin)
  if [ "$CURRENT" != "$REPO_URL" ]; then
    echo "🔄 Remote update: $CURRENT → $REPO_URL"
    git remote set-url origin "$REPO_URL"
  else
    echo "✅ remote already set: $REPO_URL"
  fi
else
  git remote add origin "$REPO_URL"
  echo "✅ remote added: $REPO_URL"
fi

# ---------- 6. Git user config (if missing) ----------
if ! git config user.email >/dev/null 2>&1; then
  echo ""
  read -p "Git email: " GIT_EMAIL
  git config user.email "$GIT_EMAIL"
fi
if ! git config user.name >/dev/null 2>&1; then
  read -p "Git name: " GIT_NAME
  git config user.name "$GIT_NAME"
fi

# ---------- 7. Commit ----------
echo ""
echo "📦 Staging files..."
git add .

echo "📊 Status summary:"
git status --short | head -20
echo ""

if git diff --cached --quiet; then
  echo "ℹ️  Kuch naya nahi hai — skip commit"
else
  read -p "Commit message (default: 'Deploy: initial'): " MSG
  MSG="${MSG:-Deploy: initial}"
  git commit -m "$MSG"
  echo "✅ Committed"
fi

# ---------- 8. Push ----------
echo ""
echo "🚀 GitHub par push kar raha hoon..."
echo ""
echo "⚠️  GitHub password accept nahi karta."
echo "   Personal Access Token chahiye:"
echo "   https://github.com/settings/tokens (scope: repo)"
echo ""
read -p "Push now? (y/N) " PUSH
if [[ "$PUSH" =~ ^[Yy]$ ]]; then
  git push -u origin main
  echo ""
  echo "✅ Pushed to $REPO_URL"
else
  echo "⏭️  Push skipped. Baad me chalao: git push -u origin main"
fi

# ---------- 9. Generate secrets for Vercel ----------
echo ""
echo "==================================================="
echo " 🔑 Environment Keys (Vercel/Railway ke liye)"
echo "==================================================="
if command -v openssl >/dev/null 2>&1; then
  echo "TOKEN_ENCRYPTION_KEY=$(openssl rand -hex 32)"
  echo "SESSION_SECRET=$(openssl rand -hex 48)"
else
  # Fallback using node
  echo "TOKEN_ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
  echo "SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
fi
echo ""
echo "👆 Ye dono values copy karke Vercel + Railway me daalo"

# ---------- 10. Vercel deploy ----------
echo ""
echo "==================================================="
echo " ▲ Vercel Deploy"
echo "==================================================="
echo ""
echo "Vercel CLI install karna hai? (auto-deploy hoga)"
read -p "Install Vercel CLI + deploy? (y/N) " VERCEL

if [[ "$VERCEL" =~ ^[Yy]$ ]]; then
  if ! command -v vercel >/dev/null 2>&1; then
    echo "📦 Installing vercel CLI..."
    npm install -g vercel
  fi

  echo ""
  echo "Vercel par login kar raha hoon..."
  vercel login

  echo ""
  echo "Deploy prod me chal raha hoon..."
  vercel --prod
  echo ""
  echo "⚠️  IMPORTANT: Vercel dashboard → Settings → Environment Variables"
  echo "   Ye daalo:"
  echo "   - DATABASE_URL       (Neon: https://neon.tech)"
  echo "   - REDIS_URL          (Upstash: https://upstash.com)"
  echo "   - GOOGLE_CLIENT_ID"
  echo "   - GOOGLE_CLIENT_SECRET"
  echo "   - GOOGLE_REDIRECT_URI = https://<your-app>.vercel.app/api/oauth/google/callback"
  echo "   - TOKEN_ENCRYPTION_KEY (upar generate hua)"
  echo "   - SESSION_SECRET       (upar generate hua)"
  echo "   - APP_URL              = https://<your-app>.vercel.app"
  echo ""
  echo "   Then: vercel --prod  (redeploy)"
else
  echo "⏭️  Skipped. Manual deploy ke liye:"
  echo "   1. https://vercel.com/new → Import '$REPO_NAME'"
  echo "   2. Framework: Next.js"
  echo "   3. Build Command: prisma generate && next build"
  echo "   4. Environment variables daalo (niche list dekho)"
fi

# ---------- 11. Railway worker deploy ----------
echo ""
echo "==================================================="
echo " 🚂 Railway Worker Deploy (BullMQ)"
echo "==================================================="
echo ""
echo "Vercel par worker NAHI chalega — alag host chahiye."
echo ""
echo "Option 1 — Railway (recommended):"
echo "  1. https://railway.app → New Project → Deploy from GitHub"
echo "  2. Repo: $REPO_NAME"
echo "  3. Settings:"
echo "     Start Command: npm run worker"
echo "     Build Command: npm install && npx prisma generate"
echo "  4. Variables (same as Vercel env):"
echo "     DATABASE_URL, REDIS_URL, GOOGLE_CLIENT_ID,"
echo "     GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI,"
echo "     TOKEN_ENCRYPTION_KEY, SESSION_SECRET, APP_URL"
echo ""
echo "Option 2 — Render:"
echo "  https://render.com → New Background Worker"
echo "  Build: npm install && npx prisma generate"
echo "  Start: npm run worker"
echo ""
echo "Option 3 — Fly.io:"
echo "  fly launch --name ${VERCEL_APP_NAME}-worker"
echo "  fly secrets set DATABASE_URL=... REDIS_URL=... GOOGLE_CLIENT_ID=..."
echo ""

# ---------- 12. Final checklist ----------
echo "==================================================="
echo " ✅ Final Checklist"
echo "==================================================="
echo ""
echo " [ ] GitHub push ho gaya       → $REPO_URL"
echo " [ ] Neon Postgres bana        → https://neon.tech"
echo " [ ] Upstash Redis bana        → https://upstash.com"
echo " [ ] Vercel import + env vars"
echo " [ ] Vercel: prisma db push    → local se: DATABASE_URL=... npx prisma db push"
echo " [ ] Google OAuth redirect URI → https://your-app.vercel.app/api/oauth/google/callback"
echo " [ ] Railway worker deploy"
echo " [ ] Test: curl https://your-app.vercel.app/api/health"
echo ""
echo "==================================================="
echo " 🎉 Deploy script complete!"
echo "==================================================="