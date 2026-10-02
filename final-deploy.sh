#!/usr/bin/env bash
set -e

# ================================================
#  🚀 EmailCampaign — Final Deploy Fix + Guide
#  GitHub: https://github.com/dipenzala/emailcampaign.git
# ================================================

REPO_URL="https://github.com/dipenzala/emailcampaign.git"

echo "==================================================="
echo " 🚀 EmailCampaign — Final Deploy"
echo "==================================================="

# ---------- 0. Locate project ----------
cd "$(dirname "$0")" 2>/dev/null || true

if [ ! -f "package.json" ]; then
  echo "❌ package.json nahi mila. Project root me chalao."
  exit 1
fi
echo "📁 $(pwd)"

# ---------- 1. CRLF safety (Windows) ----------
echo ""
echo "🔧 Line endings fix..."
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅ Done"

# ---------- 2. Fix package.json (tsx move) ----------
echo ""
echo "📦 package.json fix (tsx/typescript/prisma → dependencies)..."
node -e '
const fs=require("fs");
const pkg=JSON.parse(fs.readFileSync("package.json","utf8"));
const move=["tsx","typescript","prisma"];
let moved=[];
move.forEach(p=>{
  if(pkg.devDependencies && pkg.devDependencies[p]){
    pkg.dependencies[p]=pkg.devDependencies[p];
    delete pkg.devDependencies[p];
    moved.push(p);
  }
});
if(!pkg.dependencies["dotenv"]) pkg.dependencies["dotenv"]="^16.4.5";
fs.writeFileSync("package.json", JSON.stringify(pkg,null,2));
console.log("   Moved:", moved.join(", ") || "none (already fixed)");
'
echo "✅ package.json updated"

# ---------- 3. Procfile ----------
echo ""
echo "📝 Procfile create..."
cat > Procfile <<'EOF'
worker: npm run worker
EOF
sed -i 's/\r$//' Procfile
echo "✅ Procfile: $(cat Procfile)"

# ---------- 4. .gitattributes ----------
echo ""
echo "📝 .gitattributes (LF enforcement)..."
cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
Procfile text eol=lf
Dockerfile* text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.json text eol=lf
*.md text eol=lf
EOF
sed -i 's/\r$//' .gitattributes
echo "✅ .gitattributes ready"

# ---------- 5. .gitignore check ----------
echo ""
if [ ! -f ".gitignore" ] || ! grep -q node_modules .gitignore; then
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
.vscode/
.idea/
.DS_Store
.vercel
next-env.d.ts
EOF
  sed -i 's/\r$//' .gitignore
  echo "✅ .gitignore created"
else
  echo "✅ .gitignore already present"
fi

# ---------- 6. Git setup ----------
echo ""
if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi

if git remote get-url origin >/dev/null 2>&1; then
  CUR=$(git remote get-url origin)
  [ "$CUR" != "$REPO_URL" ] && git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi
echo "✅ Remote: $(git remote get-url origin)"

# Untrack .env if accidentally tracked
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  git rm --cached .env >/dev/null 2>&1 || true
  echo "🔒 .env untracked"
fi

# ---------- 7. Commit + push ----------
echo ""
git add .
if git diff --cached --quiet; then
  echo "ℹ️  Kuch naya nahi. Skip commit."
else
  git commit -m "Fix: runtime deps + Procfile + gitattributes" >/dev/null
  echo "✅ Committed"
fi

echo ""
read -p "🚀 GitHub push karein? (y/N) " PUSH
if [[ "$PUSH" =~ ^[Yy]$ ]]; then
  git push -u origin main
  echo "✅ Pushed"
fi

# ---------- 8. Generate secrets ----------
echo ""
echo "==================================================="
echo " 🔑 Generate Secrets (Vercel + Northflank me daalo)"
echo "==================================================="
if command -v openssl >/dev/null 2>&1; then
  echo "TOKEN_ENCRYPTION_KEY=$(openssl rand -hex 32)"
  echo "SESSION_SECRET=$(openssl rand -hex 48)"
else
  echo "TOKEN_ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
  echo "SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
fi

# ---------- 9. Full ENV template ----------
echo ""
echo "==================================================="
echo " 📋 ENV VARS — Dono jagah SAME daalo"
echo "==================================================="
echo ""
cat <<'ENVHELP'
DATABASE_URL          → Neon Postgres URL
                        (https://neon.tech)
                        Format: postgresql://user:pass@ep-xxx.aws.neon.tech/neondb?sslmode=require

REDIS_URL             → Upstash Redis URL (wasaas-redis reuse karo)
                        (https://console.upstash.com)
                        Format: rediss://default:xxx@ap-south-1-xxx.upstash.io:6379
                        ⚠️  rediss:// (double-s) — single redis:// kaam nahi karega

GOOGLE_CLIENT_ID      → Google Cloud Console
GOOGLE_CLIENT_SECRET  → Google Cloud Console
                        (https://console.cloud.google.com → APIs & Services → Credentials)

GOOGLE_REDIRECT_URI   → https://<your-app>.vercel.app/api/oauth/google/callback

TOKEN_ENCRYPTION_KEY  → upar generate hua (64 hex chars)
SESSION_SECRET        → upar generate hua (96 hex chars)

APP_URL               → https://<your-app>.vercel.app
NODE_ENV              → production
ENVHELP

# ---------- 10. Vercel guide ----------
echo ""
echo "==================================================="
echo " ▲ VERCEL SETUP (Next.js app)"
echo "==================================================="
cat <<'VERCEL'
STEP 1 — Neon Postgres banao
  1. https://neon.tech → Sign up with GitHub
  2. Create Project → Region: Singapore
  3. Connection string copy karo (postgresql://...)

STEP 2 — Upstash Redis
  1. https://console.upstash.com → wasaas-redis (existing)
  2. Connect tab → ioredis URL copy karo (rediss://...)

STEP 3 — Google OAuth
  1. https://console.cloud.google.com → New Project
  2. Enable Gmail API
  3. OAuth Consent Screen → External → scopes: gmail.send, userinfo.email
  4. Test users → apna Gmail add karo
  5. Credentials → Create OAuth Client ID (Web)
     Redirect URIs:
       http://localhost:3000/api/oauth/google/callback
       https://<your-app>.vercel.app/api/oauth/google/callback
  6. Client ID + Secret copy karo

STEP 4 — Vercel import
  1. https://vercel.com/new → Import 'emailcampaign'
  2. Framework Preset: Next.js
  3. Build Command: prisma generate && next build   ← OVERRIDE
  4. Environment Variables (9 daalo):
       DATABASE_URL, REDIS_URL, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
       GOOGLE_REDIRECT_URI, TOKEN_ENCRYPTION_KEY, SESSION_SECRET,
       APP_URL, NODE_ENV=production
  5. Deploy click karo

STEP 5 — Deploy ke baad
  - Vercel URL note karo (e.g. emailcampaign-abc.vercel.app)
  - Settings → Environment Variables me GOOGLE_REDIRECT_URI aur APP_URL
    apne actual URL se update karo
  - Redeploy karo

STEP 6 — DB schema push (local se)
  export DATABASE_URL="postgresql://...neon..."
  npx prisma db push
VERCEL

# ---------- 11. Northflank guide ----------
echo ""
echo "==================================================="
echo " ⚙️  NORTHFLANK SETUP (BullMQ Worker)"
echo "==================================================="
cat <<'NF'
STEP 1 — Account
  1. https://northflank.com → Sign up with GitHub
  2. Developer Sandbox (free) plan select karo
  3. Region: Delhi (ya Asia-South) recommended

STEP 2 — Project
  1. Create Project → Name: emailcampaign
  2. Region lock karo (baad me change nahi hota)

STEP 3 — GitHub connect
  1. Top banner "Link now" click karo
  2. GitHub authorize → repo 'dipenzala/emailcampaign' select

STEP 4 — Service create
  1. Project me → "Deploy repository"
  2. Repository: dipenzala/emailcampaign
  3. Branch: main
  4. Service type: Combined (ya Service)
  5. Service name: emailcampaign-worker
  6. Build type: Buildpack (Heroku builder:24)
  7. Build context: /

STEP 5 — Compute plan
  ⚠️  nf-compute-20 select karo (0.2 vCPU / 512 MB)
      nf-compute-10 (256 MB) kam hai, worker OOM ho sakta hai

STEP 6 — Environment variables (9 SAME as Vercel)
  DATABASE_URL, REDIS_URL, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
  GOOGLE_REDIRECT_URI, TOKEN_ENCRYPTION_KEY, SESSION_SECRET,
  APP_URL, NODE_ENV=production

  ⚠️  TOKEN_ENCRYPTION_KEY Vercel wali SAME honi chahiye
      warna OAuth tokens decrypt nahi honge

STEP 7 — Deploy
  Create Service click karo → 2-4 min build

STEP 8 — Logs verify
  Deploy hone ke baad Logs tab me dikhna chahiye:
    [INFO] Successfully fetched environment variables
    > emailcampaign@1.0.0 worker
    > tsx workers/sender.worker.ts
    🚀 Sender worker running…

  ✅ Ye dikha = WORKER LIVE!

STEP 9 — Agar rebuild trigger nahi hua
  Service → Builds tab → "Trigger build" click karo

  Ya git push ke baad CI auto-trigger karega (green toggle check karo)
NF

# ---------- 12. Final checklist ----------
echo ""
echo "==================================================="
echo " ✅ FINAL CHECKLIST"
echo "==================================================="
cat <<'CHECK'
[ ] GitHub push complete
[ ] Neon Postgres ready
[ ] Upstash Redis ready (wasaas-redis)
[ ] Google OAuth credentials ready
[ ] Vercel: import + 9 env vars + deploy
[ ] Vercel: prisma db push (local se)
[ ] Vercel: GOOGLE_REDIRECT_URI update + redeploy
[ ] Northflank: service create + nf-compute-20
[ ] Northflank: 9 env vars (SAME as Vercel)
[ ] Northflank: logs me "🚀 Sender worker running…"
[ ] Test: curl https://<app>.vercel.app/api/health
[ ] Test: sender connect karo (/senders)
[ ] Test: chhota campaign (5 emails) chalao
CHECK

echo ""
echo "==================================================="
echo " 🎉 Done! Upar ke guides follow karo."
echo "==================================================="