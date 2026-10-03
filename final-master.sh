#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🚀 FINAL MASTER — EmailCampaign"
echo " Domain: emailcampaign-ten.vercel.app"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF fix ----------
find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.prisma" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo "✅ CRLF fixed"

# ---------- 2. Prisma schema ----------
echo "📝 prisma/schema.prisma..."
mkdir -p prisma
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
}
model SenderAccount {
  id              String    @id @default(cuid())
  email           String    @unique
  displayName     String?
  accessToken     String?
  refreshToken    String?
  tokenExpiry     DateTime?
  scope           String?
  status          String    @default("DISCONNECTED")
  sentToday       Int       @default(0)
  dailyLimit      Int       @default(10)
  batchCount      Int       @default(0)
  rotationOrder   Int       @default(0)
  isActive        Boolean   @default(true)
  errors          Int       @default(0)
  lastSuccessAt   DateTime?
  lastResetAt     DateTime  @default(now())
  warmupEnabled   Boolean   @default(true)
  warmupStartedAt DateTime  @default(now())
  warmupDay       Int       @default(1)
  hardBounces     Int       @default(0)
  softBounces     Int       @default(0)
  complaints      Int       @default(0)
  reputationScore Int       @default(100)
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
}
model Contact {
  id            String    @id @default(cuid())
  email         String    @unique
  name          String?
  company       String?
  phone         String?
  city          String?
  custom        Json?
  isRoleAccount Boolean   @default(false)
  isDisposable  Boolean   @default(false)
  hygieneScore  Int       @default(100)
  createdAt     DateTime  @default(now())
  recipients    CampaignRecipient[]
}
model SuppressionList {
  id        String   @id @default(cuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}
model Campaign {
  id              String   @id @default(cuid())
  name            String
  subject         String
  html            String
  status          String   @default("DRAFT")
  totalCount      Int      @default(0)
  sentCount       Int      @default(0)
  deliveredCount  Int      @default(0)
  failedCount     Int      @default(0)
  bouncedCount    Int      @default(0)
  suppressedCount Int      @default(0)
  batchLimit      Int      @default(10)
  spamScore       Int?
  spamIssues      Json?
  createdAt       DateTime @default(now())
  startedAt       DateTime?
  completedAt     DateTime?
  recipients      CampaignRecipient[]
}
model CampaignRecipient {
  id                String    @id @default(cuid())
  campaignId        String
  contactId         String
  senderAccountId   String?
  status            String    @default("QUEUED")
  providerMessageId String?
  errorCode         String?
  errorMessage      String?
  attemptCount      Int       @default(0)
  queuedAt          DateTime  @default(now())
  sentAt            DateTime?
  deliveredAt       DateTime?
  failedAt          DateTime?
  bouncedAt         DateTime?
  bounceType        String?
  campaign          Campaign  @relation(fields: [campaignId], references: [id], onDelete: Cascade)
  contact           Contact   @relation(fields: [contactId], references: [id])
  @@unique([campaignId, contactId])
  @@index([campaignId, status])
}
model MessageLog {
  id          String   @id @default(cuid())
  campaignId  String
  recipientId String
  level       String
  message     String
  createdAt   DateTime @default(now())
}
model AuditLog {
  id        String   @id @default(cuid())
  action    String
  meta      Json?
  createdAt DateTime @default(now())
}
PRISMA
sed -i 's/\r$//' prisma/schema.prisma
echo "✅ Schema ready"

# ---------- 3. package.json ----------
node -e '
const fs=require("fs");
const pkg=JSON.parse(fs.readFileSync("package.json","utf8"));
pkg.dependencies=pkg.dependencies||{};
pkg.devDependencies=pkg.devDependencies||{};
["tsx","typescript","prisma"].forEach(p=>{
  if(pkg.devDependencies[p]){pkg.dependencies[p]=pkg.devDependencies[p];delete pkg.devDependencies[p];}
});
pkg.dependencies["bullmq"]="^5.28.0";
pkg.scripts=pkg.scripts||{};
pkg.scripts.postinstall="echo skipping-postinstall";
pkg.scripts.build="prisma generate && prisma db push --skip-generate --accept-data-loss && next build";
pkg.scripts.worker="tsx workers/sender.worker.ts";
pkg.scripts["db:push"]="prisma db push";
pkg.scripts.dev="concurrently -n next,worker -c cyan,magenta \"next dev -p 3000\" \"tsx watch workers/sender.worker.ts\"";
pkg.scripts.start="concurrently -n next,worker -c cyan,magenta \"next start -p 3000\" \"tsx workers/sender.worker.ts\"";
fs.writeFileSync("package.json",JSON.stringify(pkg,null,2));
console.log("   ✅ package.json");
'
echo "✅ package.json ready"

# ---------- 4. .env (local) ----------
if [ ! -f ".env" ]; then
  cat > .env <<'EOF'
DATABASE_URL=""
REDIS_URL=""
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
TOKEN_ENCRYPTION_KEY=""
SESSION_SECRET=""
APP_URL="https://emailcampaign-ten.vercel.app"
EOF
  echo "✅ .env created"
fi

# ---------- 5. .env.example ----------
cat > .env.example <<'EOF'
DATABASE_URL="postgresql://..."
REDIS_URL="rediss://..."
GOOGLE_CLIENT_ID="xxx.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="GOCSPX-xxx"
GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
TOKEN_ENCRYPTION_KEY="64-hex-chars"
SESSION_SECRET="96-hex-chars"
APP_URL="https://emailcampaign-ten.vercel.app"
EOF
echo "✅ .env.example ready"

# ---------- 6. Procfile + gitattrs + gitignore ----------
printf "worker: npm run worker\n" > Procfile
sed -i 's/\r$//' Procfile
cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
Procfile text eol=lf
*.prisma text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.json text eol=lf
*.css text eol=lf
EOF
sed -i 's/\r$//' .gitattributes
if [ ! -f ".gitignore" ]; then
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
fi
echo "✅ Config files ready"

# ---------- 7. lib files ----------
mkdir -p lib

# redis
cat > lib/redis.ts <<'EOF'
import IORedis from 'ioredis';
const g = globalThis as any;
function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();
  const commonOpts = {
    maxRetriesPerRequest: 2,
    connectTimeout: 5000,
    commandTimeout: 8000,
    enableOfflineQueue: false,
    enableReadyCheck: false,
    lazyConnect: true,
    retryStrategy: (times: number) => {
      if (times > 3) return null;
      return Math.min(times * 500, 2000);
    },
  };
  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    return new IORedis({ host: '127.0.0.1', port: 6379, ...commonOpts });
  }
  return new IORedis(url, commonOpts);
}
export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
EOF

# prisma
cat > lib/prisma.ts <<'EOF'
import { PrismaClient } from '@prisma/client';
const g = globalThis as any;
export const prisma: PrismaClient = g.__prisma ?? new PrismaClient();
if (process.env.NODE_ENV !== 'production') g.__prisma = prisma;
EOF

# queue
cat > lib/queue.ts <<'EOF'
import { Queue } from 'bullmq';
import { redis } from './redis';
export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';
let _queue: Queue | null = null;
export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, { connection: redis, prefix: QUEUE_PREFIX });
  return _queue;
}
export const sendQueue = new Proxy({} as Queue, {
  get(_t, prop) {
    const q = getSendQueue();
    const v = (q as any)[prop];
    return typeof v === 'function' ? v.bind(q) : v;
  },
});
EOF

# crypto
cat > lib/crypto.ts <<'EOF'
import crypto from 'crypto';
let _key: Buffer | null = null;
function getKey(): Buffer {
  if (_key) return _key;
  const raw = (process.env.TOKEN_ENCRYPTION_KEY || '').trim();
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be 64 hex chars (got ' + raw.length + ')');
  }
  _key = Buffer.from(raw, 'hex');
  return _key;
}
export function encrypt(plain: string): string {
  const key = getKey();
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64');
}
export function decrypt(payload: string): string {
  const key = getKey();
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const d = crypto.createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(data), d.final()]).toString('utf8');
}
EOF

# session
cat > lib/session.ts <<'EOF'
import crypto from 'crypto';
const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';
export function signSession(payload: { email: string; name?: string; ts: number }) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}
export function verifySession(token?: string): { email: string; name?: string } | null {
  if (!token) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try { return JSON.parse(Buffer.from(data, 'base64url').toString()); } catch { return null; }
}
EOF

# gmail
cat > lib/gmail.ts <<'EOF'
import { google } from 'googleapis';
export function oauthClient() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;
  if (!clientId || !clientSecret || !redirectUri) {
    throw new Error('Missing OAuth env vars');
  }
  return new google.auth.OAuth2(clientId, clientSecret, redirectUri);
}
export function gmailFor(accessToken: string, refreshToken: string) {
  const c = oauthClient();
  c.setCredentials({ access_token: accessToken, refresh_token: refreshToken });
  return google.gmail({ version: 'v1', auth: c });
}
EOF

# email validator
cat > lib/email-validator.ts <<'EOF'
export function isValidEmail(e: string) {
  if (!e) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());
}
EOF

# personalization
cat > lib/personalization.ts <<'EOF'
export function renderTemplate(html: string, data: Record<string, any>) {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_m, key, def) => {
    const v = data[key];
    if (v === undefined || v === null || v === '') return def ?? '';
    return String(v);
  });
}
EOF

# mime
cat > lib/mime.ts <<'EOF'
export function buildMime(opts:{from:string;to:string;subject:string;html:string;text:string;unsubscribeUrl?:string}) {
  const boundary = '=_b_' + Math.random().toString(36).slice(2);
  const headers = [
    `From: ${opts.from}`,
    `To: ${opts.to}`,
    `Subject: =?UTF-8?B?${Buffer.from(opts.subject).toString('base64')}?=`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
  ];
  if (opts.unsubscribeUrl) {
    headers.push(`List-Unsubscribe: <${opts.unsubscribeUrl}>`);
    headers.push('List-Unsubscribe-Post: List-Unsubscribe=One-Click');
  }
  const body =
`--${boundary}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(opts.text).toString('base64')}

--${boundary}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(opts.html).toString('base64')}

--${boundary}--`;
  return headers.join('\r\n') + '\r\n\r\n' + body;
}
export function htmlToText(html: string) {
  return html.replace(/<style[\s\S]*?<\/style>/gi,'')
    .replace(/<script[\s\S]*?<\/script>/gi,'')
    .replace(/<br\s*\/?>/gi,'\n')
    .replace(/<\/p>/gi,'\n\n')
    .replace(/<[^>]+>/g,'')
    .replace(/\n{3,}/g,'\n\n')
    .trim();
}
EOF

# spam checker
cat > lib/spam-checker.ts <<'EOF'
const SPAMMY_WORDS = ['free','act now','limited time','click here','buy now','order now','cash','prize','winner','congratulations','urgent','guarantee','no risk','special promotion','make money','earn extra','work from home','cheap','discount','lowest price','risk-free','satisfaction guaranteed','dear friend','unsecured','credit','debt','viagra','casino','lottery','weight loss','as seen on'];
const SUBJECT_PATTERNS = [
  { re: /[A-Z]{5,}/, msg: '5+ uppercase letters', pts: 8 },
  { re: /!{2,}/, msg: 'Multiple !!!', pts: 6 },
  { re: /\${2,}/, msg: 'Multiple dollar signs', pts: 10 },
  { re: /\b(free|winner|prize|urgent)\b/i, msg: 'Spammy keyword', pts: 15 },
  { re: /^\s*$/, msg: 'Empty subject', pts: 20 },
];
const DISPOSABLE = new Set(['tempmail.com','guerrillamail.com','mailinator.com','10minutemail.com','throwaway.email','trashmail.com','yopmail.com','sharklasers.com','temp-mail.org','getnada.com','fakeinbox.com','maildrop.cc']);
const ROLES = new Set(['admin','info','support','sales','contact','help','noreply','no-reply','postmaster','webmaster','abuse','billing','marketing','office','hello','team']);
export type SpamIssue = { severity: 'low'|'medium'|'high'; category: string; message: string; points: number };
export type SpamReport = { score: number; issues: SpamIssue[]; ok: boolean; warning: boolean; blocked: boolean };
export function checkEmail(opts: { subject: string; html: string; fromEmail: string }): SpamReport {
  const issues: SpamIssue[] = [];
  let score = 0;
  const add = (severity: SpamIssue['severity'], category: string, message: string, points: number) => {
    issues.push({ severity, category, message, points });
    score += points;
  };
  if (!opts.subject || !opts.subject.trim()) add('high','subject','Subject empty',20);
  for (const { re, msg, pts } of SUBJECT_PATTERNS) if (re.test(opts.subject)) add('medium','subject',msg,pts);
  const html = opts.html || '';
  if (!/unsubscribe/i.test(html)) add('high','compliance','No unsubscribe link',25);
  const imgCount = (html.match(/<img[\s>]/gi) || []).length;
  const textLength = html.replace(/<[^>]+>/g, '').trim().length;
  if (imgCount > 0 && textLength < 100) add('medium','content','Mostly images',15);
  if (imgCount > 5) add('low','content','Too many images',5);
  const links = (html.match(/href=["']([^"']+)["']/gi) || []).length;
  if (links > 20) add('medium','content','Too many links',10);
  const shorteners = ['bit.ly','goo.gl','tinyurl.com','t.co','ow.ly'];
  if (shorteners.some(s => html.toLowerCase().includes(s))) add('high','content','URL shortener',20);
  const plainText = html.replace(/<[^>]+>/g, ' ');
  const letters = plainText.match(/[A-Za-z]/g) || [];
  const caps = plainText.match(/[A-Z]/g) || [];
  if (letters.length > 20 && caps.length / letters.length > 0.4) add('medium','content','Over 40% uppercase',10);
  const lower = plainText.toLowerCase();
  const found: string[] = [];
  for (const w of SPAMMY_WORDS) if (lower.includes(w)) found.push(w);
  if (found.length > 0) add('medium','content',`Spammy words: ${found.slice(0,5).join(', ')}`,Math.min(20,found.length*3));
  if (/<script[\s>]/i.test(html)) add('high','html','Contains <script>',30);
  if (/\son\w+\s*=/i.test(html)) add('medium','html','Inline event handlers',10);
  if (/https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)/i.test(html)) add('high','html','Localhost links',25);
  const finalScore = Math.min(100, score);
  return { score: finalScore, issues, ok: finalScore < 30, warning: finalScore >= 30 && finalScore < 50, blocked: finalScore >= 50 };
}
export function checkEmailHygiene(email: string) {
  const [local, domain] = email.toLowerCase().split('@');
  const isRole = ROLES.has(local);
  const isDisp = DISPOSABLE.has(domain);
  let s = 100;
  if (isRole) s -= 20;
  if (isDisp) s -= 60;
  return { isRoleAccount: isRole, isDisposable: isDisp, score: Math.max(0, s) };
}
EOF

# warmup
cat > lib/warmup.ts <<'EOF'
import { prisma } from './prisma';
const TIERS = [
  { maxDay: 3, limit: 5 },
  { maxDay: 7, limit: 10 },
  { maxDay: 14, limit: 25 },
  { maxDay: 30, limit: 50 },
];
export function effectiveLimit(sender: { warmupEnabled: boolean; warmupDay: number; dailyLimit: number }): number {
  if (!sender.warmupEnabled) return sender.dailyLimit;
  const tier = TIERS.find(t => sender.warmupDay <= t.maxDay);
  if (!tier) return sender.dailyLimit;
  return Math.min(tier.limit, sender.dailyLimit);
}
export async function advanceWarmup(): Promise<number> {
  const now = new Date();
  const senders = await prisma.senderAccount.findMany({ where: { warmupEnabled: true, status: 'CONNECTED' } });
  let updated = 0;
  for (const s of senders) {
    const days = Math.floor((now.getTime() - s.warmupStartedAt.getTime()) / (1000*60*60*24)) + 1;
    if (days !== s.warmupDay) {
      await prisma.senderAccount.update({ where: { id: s.id }, data: { warmupDay: days } });
      updated++;
    }
  }
  return updated;
}
EOF

# bounce handler
cat > lib/bounce-handler.ts <<'EOF'
import { prisma } from './prisma';
export async function handleBounce(opts: { email: string; senderAccountId: string | null; bounceType: 'HARD'|'SOFT'|'COMPLAINT' }) {
  const { email, senderAccountId, bounceType } = opts;
  if (bounceType === 'HARD' || bounceType === 'COMPLAINT') {
    await prisma.suppressionList.upsert({
      where: { email },
      create: { email, reason: bounceType === 'HARD' ? 'BOUNCED' : 'COMPLAINT' },
      update: { reason: bounceType === 'HARD' ? 'BOUNCED' : 'COMPLAINT' },
    });
  }
  if (senderAccountId) {
    if (bounceType === 'HARD') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { hardBounces: { increment: 1 }, reputationScore: { decrement: 5 } } });
    else if (bounceType === 'SOFT') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { softBounces: { increment: 1 }, reputationScore: { decrement: 1 } } });
    else if (bounceType === 'COMPLAINT') await prisma.senderAccount.update({ where: { id: senderAccountId }, data: { complaints: { increment: 1 }, reputationScore: { decrement: 20 } } });
  }
}
EOF

# rate guard
cat > lib/rate-guard.ts <<'EOF'
import { prisma } from './prisma';
import { effectiveLimit } from './warmup';
export async function remainingToday(senderId: string): Promise<number> {
  const s = await prisma.senderAccount.findUnique({ where: { id: senderId } });
  if (!s) return 0;
  const isWorkspace = !/@gmail\.com$/i.test(s.email);
  const providerCap = isWorkspace ? 2000 : 500;
  const warmupCap = effectiveLimit({ warmupEnabled: s.warmupEnabled, warmupDay: s.warmupDay, dailyLimit: s.dailyLimit });
  return Math.max(0, Math.min(providerCap, warmupCap, s.dailyLimit) - s.sentToday);
}
export async function canSend(senderId: string): Promise<boolean> {
  return (await remainingToday(senderId)) > 0;
}
EOF

# sender rotation
cat > lib/sender-rotation.ts <<'EOF'
import { prisma } from './prisma';
export async function pickNextSender(opts: { batchLimit: number }) {
  const { batchLimit } = opts;
  const senders = await prisma.senderAccount.findMany({
    where: { status: 'CONNECTED', refreshToken: { not: null }, isActive: true },
    orderBy: [{ sentToday: 'asc' }, { lastSuccessAt: 'asc' }, { rotationOrder: 'asc' }],
  });
  for (const s of senders) if (s.batchCount < batchLimit) return s;
  await prisma.senderAccount.updateMany({ where: { status: 'CONNECTED', isActive: true }, data: { batchCount: 0 } });
  return senders[0] ?? null;
}
export async function markSenderUsed(senderId: string) {
  return prisma.senderAccount.update({
    where: { id: senderId },
    data: { sentToday: { increment: 1 }, batchCount: { increment: 1 }, lastSuccessAt: new Date() },
  });
}
export async function resetDailyCounters() {
  const sod = new Date();
  sod.setHours(0, 0, 0, 0);
  const r = await prisma.senderAccount.updateMany({ where: { lastResetAt: { lt: sod } }, data: { sentToday: 0, batchCount: 0, lastResetAt: new Date() } });
  return r.count;
}
EOF

# list hygiene
cat > lib/list-hygiene.ts <<'EOF'
import { checkEmailHygiene } from './spam-checker';
export type HygieneResult = {
  valid: any[];
  rejected: { email: string; reason: string }[];
  stats: { total: number; valid: number; roleAccounts: number; disposable: number; invalidFormat: number };
};
export function cleanList(rows: any[]): HygieneResult {
  const result: HygieneResult = { valid: [], rejected: [], stats: { total: rows.length, valid: 0, roleAccounts: 0, disposable: 0, invalidFormat: 0 } };
  const seen = new Set<string>();
  for (const row of rows) {
    const email = String(row.email || '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      result.rejected.push({ email, reason: 'INVALID_FORMAT' });
      result.stats.invalidFormat++;
      continue;
    }
    if (seen.has(email)) { result.rejected.push({ email, reason: 'DUPLICATE' }); continue; }
    seen.add(email);
    const hygiene = checkEmailHygiene(email);
    if (hygiene.isDisposable) { result.rejected.push({ email, reason: 'DISPOSABLE_DOMAIN' }); result.stats.disposable++; continue; }
    if (hygiene.isRoleAccount) result.stats.roleAccounts++;
    result.valid.push({ ...row, email, hygieneScore: hygiene.score, isRoleAccount: hygiene.isRoleAccount, isDisposable: false });
    result.stats.valid++;
  }
  return result;
}
EOF

echo "✅ All lib files ready"

# ---------- 8. Worker ----------
mkdir -p workers
cat > workers/sender.worker.ts <<'EOF'
import 'dotenv/config';
import { Worker, Job } from 'bullmq';
import { prisma } from '../lib/prisma';
import { redis } from '../lib/redis';
import { SEND_QUEUE, QUEUE_PREFIX } from '../lib/queue';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSender, markSenderUsed } from '../lib/sender-rotation';
import { effectiveLimit } from '../lib/warmup';
import { handleBounce } from '../lib/bounce-handler';
async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });
  const raw = buildMime({ from: `${sender.displayName ?? sender.email} <${sender.email}>`, to, subject, html, text, unsubscribeUrl: unsubUrl });
  const res = await gmail.users.messages.send({ userId: 'me', requestBody: { raw: Buffer.from(raw).toString('base64url') } });
  return { id: res.data.id, access, refresh };
}
const worker = new Worker(SEND_QUEUE, async (job: Job) => {
  const { campaignId, recipientId } = job.data;
  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) throw new Error('Campaign missing');
  if (campaign.status === 'PAUSED') throw new Error('PAUSED');
  if (campaign.status === 'STOPPED') return { skipped: true };
  const r = await prisma.campaignRecipient.findUnique({ where: { id: recipientId }, include: { contact: true } });
  if (!r) return;
  if (r.status === 'SENT' || r.status === 'DELIVERED') return { alreadySent: true };
  await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'PROCESSING', attemptCount: r.attemptCount + 1 } });
  const sup = await prisma.suppressionList.findUnique({ where: { email: r.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason } });
    await prisma.campaign.update({ where: { id: campaignId }, data: { suppressedCount: { increment: 1 } } });
    return;
  }
  const sender = await pickNextSender({ batchLimit: campaign.batchLimit ?? 10 });
  if (!sender) throw new Error('No authorized sender available');
  const cap = effectiveLimit({ warmupEnabled: sender.warmupEnabled, warmupDay: sender.warmupDay, dailyLimit: sender.dailyLimit });
  if (sender.sentToday >= cap) {
    console.log(`⏸️  Warm-up cap reached for ${sender.email} (${sender.sentToday}/${cap})`);
    throw new Error('Sender warm-up limit reached');
  }
  console.log(`📤 [ROTATION] ${sender.email} (sentToday=${sender.sentToday}, batch=${sender.batchCount}/${campaign.batchLimit}, warmupDay=${sender.warmupDay})`);
  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(r.contact.email).toString('base64url')}`;
  const personalizedHtml = renderTemplate(campaign.html, {
    name: r.contact.name ?? '', email: r.contact.email, company: r.contact.company ?? '', city: r.contact.city ?? '', phone: r.contact.phone ?? '',
  });
  const text = htmlToText(personalizedHtml);
  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(sender, r.contact.email, campaign.subject, personalizedHtml, text, unsubUrl);
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SENT', senderAccountId: sender.id, providerMessageId, sentAt: new Date(), errorCode: null, errorMessage: null },
    });
    await prisma.campaign.update({ where: { id: campaignId }, data: { sentCount: { increment: 1 } } });
    await markSenderUsed(sender.id);
    if (access && refresh) {
      await prisma.senderAccount.update({ where: { id: sender.id }, data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) } });
    }
    const remaining = await prisma.campaignRecipient.count({ where: { campaignId, status: { in: ['QUEUED','PROCESSING'] } } });
    if (remaining === 0) {
      await prisma.campaign.update({ where: { id: campaignId }, data: { status: 'COMPLETED', completedAt: new Date() } });
    }
    return { ok: true, sender: sender.email };
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);
    const retryable = !isBounce && (/rate|quota|429|500|502|503|timeout|ECONN/i.test(msg) || code === 429);
    if (isBounce) {
      await handleBounce({ email: r.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'BOUNCED', errorCode: 'BOUNCED', errorMessage: msg, failedAt: new Date(), bounceType: 'HARD' } });
      await prisma.campaign.update({ where: { id: campaignId }, data: { failedCount: { increment: 1 }, bouncedCount: { increment: 1 } } });
      return { bounced: true };
    }
    if (!retryable) {
      await prisma.campaignRecipient.update({ where: { id: recipientId }, data: { status: 'FAILED', errorCode: String(code), errorMessage: msg, failedAt: new Date() } });
      await prisma.campaign.update({ where: { id: campaignId }, data: { failedCount: { increment: 1 } } });
      return { failed: true };
    }
    throw err;
  }
}, {
  connection: redis,
  prefix: QUEUE_PREFIX,
  concurrency: 4,
  limiter: { max: 10, duration: 1000 },
});
worker.on('failed', async (job, err) => {
  if (job && err.message === 'PAUSED') await job.retry().catch(() => {});
});
worker.on('completed', j => console.log('✅', j.id));
worker.on('error', e => console.error('worker error', e));
console.log('🚀 Sender worker running (rotation + warmup + anti-spam)…');
EOF
sed -i 's/\r$//' workers/sender.worker.ts
echo "✅ Worker ready"

# ---------- 9. API Routes ----------
mkdir -p app/api/health app/api/auth/login app/api/auth/logout app/api/auth/me app/api/senders app/api/senders/rotation app/api/contacts/upload app/api/campaigns app/api/test-email app/api/anti-spam/check app/api/queue/health app/api/debug/env
mkdir -p 'app/api/campaigns/[id]/start' 'app/api/campaigns/[id]/pause' 'app/api/campaigns/[id]/resume' 'app/api/campaigns/[id]/stop' 'app/api/campaigns/[id]/status' 'app/api/campaigns/[id]/stream' 'app/api/campaigns/[id]/recipients' 'app/api/campaigns/[id]/retry-queue'
mkdir -p app/api/oauth/google/start app/api/oauth/google/callback
mkdir -p 'app/api/unsubscribe/[token]'

# health
cat > app/api/health/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(){ return NextResponse.json({ ok:true, ts:Date.now(), domain: process.env.APP_URL }); }
EOF

# auth
cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { signSession } from '@/lib/session';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(req: Request) {
  const { email, name } = await req.json();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return NextResponse.json({ error: 'Valid email required' }, { status: 400 });
  const cleanEmail = String(email).toLowerCase().trim();
  try { await prisma.user.upsert({ where: { email: cleanEmail }, create: { email: cleanEmail, name: name || cleanEmail.split('@')[0] }, update: {} }); } catch {}
  const token = signSession({ email: cleanEmail, name: name || cleanEmail.split('@')[0], ts: Date.now() });
  const res = NextResponse.json({ ok: true, email: cleanEmail });
  res.cookies.set('ec_session', token, { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'lax', path: '/', maxAge: 60*60*24*30 });
  return res;
}
EOF
cat > app/api/auth/logout/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set('ec_session', '', { path: '/', maxAge: 0 });
  return res;
}
EOF
cat > app/api/auth/me/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { verifySession } from '@/lib/session';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const token = cookies().get('ec_session')?.value;
  const user = verifySession(token);
  if (!user) return NextResponse.json({ user: null }, { status: 401 });
  return NextResponse.json({ user: { email: user.email, name: user.name } });
}
EOF

# senders
cat > app/api/senders/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const list = await prisma.senderAccount.findMany({ orderBy: { createdAt: 'asc' } });
  return NextResponse.json(list.map(s => ({
    id: s.id, email: s.email, displayName: s.displayName, status: s.status,
    sentToday: s.sentToday, errors: s.errors, lastSuccessAt: s.lastSuccessAt,
    authorized: s.status === 'CONNECTED' && !!s.refreshToken,
  })));
}
EOF

# rotation
cat > app/api/senders/rotation/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { resetDailyCounters } from '@/lib/sender-rotation';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const senders = await prisma.senderAccount.findMany({
    orderBy: [{ rotationOrder: 'asc' }, { createdAt: 'asc' }],
    select: { id:true, email:true, displayName:true, status:true, isActive:true, sentToday:true, dailyLimit:true, batchCount:true, rotationOrder:true, errors:true, lastSuccessAt:true, warmupEnabled:true, warmupDay:true, reputationScore:true, hardBounces:true, softBounces:true, complaints:true },
  });
  return NextResponse.json({ senders });
}
export async function POST(req: Request) {
  const { id, dailyLimit, rotationOrder, isActive, warmupEnabled } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });
  const data: any = {};
  if (typeof dailyLimit === 'number') data.dailyLimit = dailyLimit;
  if (typeof rotationOrder === 'number') data.rotationOrder = rotationOrder;
  if (typeof isActive === 'boolean') data.isActive = isActive;
  if (typeof warmupEnabled === 'boolean') data.warmupEnabled = warmupEnabled;
  const updated = await prisma.senderAccount.update({ where: { id }, data });
  return NextResponse.json({ ok: true, sender: updated });
}
export async function PUT() {
  const count = await resetDailyCounters();
  return NextResponse.json({ ok: true, reset: count });
}
EOF

# contacts upload
cat > app/api/contacts/upload/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import * as XLSX from 'xlsx';
import { prisma } from '@/lib/prisma';
import { isValidEmail } from '@/lib/email-validator';
import { checkEmailHygiene } from '@/lib/spam-checker';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(req: Request) {
  const form = await req.formData();
  const file = form.get('file') as File | null;
  if (!file) return NextResponse.json({ error: 'No file' }, { status: 400 });
  const buf = Buffer.from(await file.arrayBuffer());
  const wb = XLSX.read(buf, { type: 'buffer' });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rows: any[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });
  const totalRows = rows.length;
  let invalid = 0, duplicates = 0, suppressed = 0, disposable = 0, roleAccounts = 0;
  const seen = new Set<string>();
  const valid: any[] = [];
  const suppression = new Set((await prisma.suppressionList.findMany()).map(s => s.email.toLowerCase()));
  const emailKey = (r: any) => Object.keys(r).find(k => /e-?mail/i.test(k));
  for (const r of rows) {
    const ek = emailKey(r);
    const email = ek ? String(r[ek]).trim().toLowerCase() : '';
    if (!email || !isValidEmail(email)) { invalid++; continue; }
    if (seen.has(email)) { duplicates++; continue; }
    seen.add(email);
    if (suppression.has(email)) { suppressed++; continue; }
    const hy = checkEmailHygiene(email);
    if (hy.isDisposable) { disposable++; continue; }
    if (hy.isRoleAccount) roleAccounts++;
    valid.push({
      email,
      name: r.Name ?? r.name ?? '',
      company: r.Company ?? r.company ?? '',
      phone: r.Phone ?? r.phone ?? '',
      city: r.City ?? r.city ?? '',
      isRoleAccount: hy.isRoleAccount,
      hygieneScore: hy.score,
    });
  }
  await Promise.all(valid.map(v => prisma.contact.upsert({
    where: { email: v.email },
    create: { email: v.email, name: v.name, company: v.company, phone: v.phone, city: v.city, isRoleAccount: v.isRoleAccount, hygieneScore: v.hygieneScore },
    update: { name: v.name, company: v.company, phone: v.phone, city: v.city, isRoleAccount: v.isRoleAccount, hygieneScore: v.hygieneScore },
  })));
  return NextResponse.json({ totalRows, valid: valid.length, invalid, duplicates, suppressed, disposable, roleAccounts, contacts: valid });
}
EOF

# campaigns
cat > app/api/campaigns/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
const Schema = z.object({
  name: z.string().min(1),
  subject: z.string().min(1),
  html: z.string().min(20),
  emails: z.array(z.string().email()).min(1),
  batchLimit: z.number().int().min(1).max(500).optional(),
});
export async function POST(req: Request) {
  const parsed = Schema.safeParse(await req.json());
  if (!parsed.success) return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  const { name, subject, html, emails, batchLimit } = parsed.data;
  const contacts = await prisma.contact.findMany({ where: { email: { in: emails } } });
  const suppressed = new Set((await prisma.suppressionList.findMany()).map(s => s.email));
  const campaign = await prisma.campaign.create({ data: { name, subject, html, totalCount: contacts.length, status: 'DRAFT', batchLimit: batchLimit ?? 10 } });
  for (const c of contacts) {
    await prisma.campaignRecipient.create({ data: { campaignId: campaign.id, contactId: c.id, status: suppressed.has(c.email) ? 'SUPPRESSED' : 'QUEUED' } });
  }
  return NextResponse.json({ id: campaign.id });
}
export async function GET() {
  const list = await prisma.campaign.findMany({ orderBy: { createdAt: 'desc' } });
  return NextResponse.json(list);
}
EOF

# campaign start
cat > 'app/api/campaigns/[id]/start/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
import { checkEmail } from '@/lib/spam-checker';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;
async function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([p, new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`${label} timeout`)), ms))]);
}
export async function POST(_: Request, { params }: { params: { id: string } }) {
  const t0 = Date.now();
  try {
    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({ subject: campaign.subject, html: campaign.html, fromEmail: sender?.email || 'noreply@example.com' });
    await prisma.campaign.update({ where: { id: params.id }, data: { spamScore: report.score, spamIssues: report.issues as any } });
    if (report.blocked) return NextResponse.json({ error: 'Spam score too high', score: report.score, issues: report.issues }, { status: 400 });
    await prisma.campaign.update({ where: { id: params.id }, data: { status: 'RUNNING', startedAt: new Date() } });
    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0, message: 'No pending recipients' });
    let queued = 0;
    let queueError: string | null = null;
    try {
      const q = getSendQueue();
      await withTimeout(new Promise<void>((resolve, reject) => {
        if ((q as any).client) {
          const conn = (q as any).client;
          if (conn.status === 'ready') return resolve();
          conn.once('ready', () => resolve());
          conn.once('error', (e: any) => reject(e));
        } else resolve();
      }), 5000, 'Redis ready');
      const jobs = recips.map((r) => ({
        name: 'send',
        data: { campaignId: params.id, recipientId: r.id },
        opts: { jobId: `${params.id}:${r.id}`, attempts: 4, backoff: { type: 'exponential' as const, delay: 5000 }, removeOnComplete: 1000, removeOnFail: 5000 },
      }));
      await withTimeout(q.addBulk(jobs), 8000, 'addBulk');
      queued = jobs.length;
    } catch (qerr: any) {
      queueError = qerr?.message || String(qerr);
      console.error('[start] Queue error:', queueError);
    }
    return NextResponse.json({ ok: true, queued, total: recips.length, spamScore: report.score, queueError: queueError || undefined, elapsed: Date.now() - t0 });
  } catch (err: any) {
    console.error('[start] Fatal:', err);
    return NextResponse.json({ error: 'Failed to start', message: err?.message ?? String(err), elapsed: Date.now() - t0 }, { status: 500 });
  }
}
EOF

# campaign status
cat > 'app/api/campaigns/[id]/status/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(_: Request, { params }: { params: { id: string } }) {
  const c = await prisma.campaign.findUnique({ where: { id: params.id } });
  if (!c) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  const counts = await prisma.campaignRecipient.groupBy({ by: ['status'], where: { campaignId: params.id }, _count: { _all: true } });
  const byStatus: Record<string, number> = {};
  counts.forEach(g => (byStatus[g.status] = g._count._all));
  const pending = (byStatus.QUEUED ?? 0) + (byStatus.PROCESSING ?? 0);
  const progress = c.totalCount ? ((c.totalCount - pending) / c.totalCount) * 100 : 0;
  return NextResponse.json({
    campaign: c,
    counts: {
      total: c.totalCount, queued: byStatus.QUEUED ?? 0, processing: byStatus.PROCESSING ?? 0,
      sent: byStatus.SENT ?? 0, delivered: byStatus.DELIVERED ?? 0, failed: byStatus.FAILED ?? 0,
      bounced: byStatus.BOUNCED ?? 0, suppressed: byStatus.SUPPRESSED ?? 0, pending,
      progress: Number(progress.toFixed(2)),
    },
    updatedAt: Date.now(),
  });
}
EOF

# campaign recipients
cat > 'app/api/campaigns/[id]/recipients/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const url = new URL(req.url);
  const status = url.searchParams.get('status');
  const where: any = { campaignId: params.id };
  if (status && status !== 'ALL') where.status = status;
  const list = await prisma.campaignRecipient.findMany({ where, take: 500, orderBy: { queuedAt: 'asc' }, include: { contact: true } });
  return NextResponse.json(list.map(r => ({ id: r.id, email: r.contact.email, name: r.contact.name, status: r.status, error: r.errorMessage, sentAt: r.sentAt, sender: r.senderAccountId })));
}
EOF

# campaign actions
for act in pause resume stop; do
  case $act in
    pause) BODY='await prisma.campaign.update({ where:{id:params.id}, data:{status:"PAUSED"} }); return NextResponse.json({ ok:true });' ;;
    resume) BODY='await prisma.campaign.update({ where:{id:params.id}, data:{status:"RUNNING"} }); return NextResponse.json({ ok:true });' ;;
    stop) BODY='await prisma.campaign.update({ where:{id:params.id}, data:{status:"STOPPED"} }); return NextResponse.json({ ok:true });' ;;
  esac
  cat > "app/api/campaigns/[id]/$act/route.ts" <<EOF
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(_: Request, { params }: { params: { id: string } }) {
  $BODY
}
EOF
done

# retry queue
cat > 'app/api/campaigns/[id]/retry-queue/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSendQueue } from '@/lib/queue';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(_: Request, { params }: { params: { id: string } }) {
  try {
    const recips = await prisma.campaignRecipient.findMany({ where: { campaignId: params.id, status: 'QUEUED' }, select: { id: true } });
    if (recips.length === 0) return NextResponse.json({ ok: true, queued: 0, message: 'Nothing to queue' });
    const q = getSendQueue();
    const jobs = recips.map((r) => ({
      name: 'send',
      data: { campaignId: params.id, recipientId: r.id },
      opts: { jobId: `${params.id}:${r.id}`, attempts: 4, backoff: { type: 'exponential' as const, delay: 5000 }, removeOnComplete: 1000, removeOnFail: 5000 },
    }));
    await q.addBulk(jobs);
    return NextResponse.json({ ok: true, queued: jobs.length });
  } catch (err: any) {
    return NextResponse.json({ error: 'Queue retry failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF

# queue health
cat > app/api/queue/health/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { redis } from '@/lib/redis';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const t0 = Date.now();
  try {
    const ping = await Promise.race([redis.ping(), new Promise<string>((_, rej) => setTimeout(() => rej(new Error('ping timeout')), 5000))]);
    return NextResponse.json({ ok: true, redis: ping, status: (redis as any).status, elapsed: Date.now() - t0, domain: process.env.APP_URL });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message ?? String(err), status: (redis as any).status, url_present: !!process.env.REDIS_URL, elapsed: Date.now() - t0, domain: process.env.APP_URL }, { status: 500 });
  }
}
EOF

# anti-spam check
cat > app/api/anti-spam/check/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { checkEmail } from '@/lib/spam-checker';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(req: Request) {
  const { subject, html, fromEmail } = await req.json();
  if (!subject || !html) return NextResponse.json({ error: 'subject and html required' }, { status: 400 });
  return NextResponse.json(checkEmail({ subject, html, fromEmail: fromEmail || 'noreply@example.com' }));
}
EOF

# debug env
cat > app/api/debug/env/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET() {
  const info = (name: string) => {
    const v = process.env[name] || '';
    return {
      present: !!v, length: v.length,
      valid: name === 'TOKEN_ENCRYPTION_KEY' ? /^[0-9a-fA-F]{64}$/.test(v)
        : name === 'REDIS_URL' ? /^rediss?:\/\/[^\s]+$/.test(v)
        : name === 'DATABASE_URL' ? /^postgres(ql)?:\/\//.test(v)
        : name === 'GOOGLE_CLIENT_ID' ? /\.apps\.googleusercontent\.com$/.test(v)
        : name === 'GOOGLE_REDIRECT_URI' ? /^https?:\/\//.test(v) : undefined,
      preview: ['APP_URL','GOOGLE_REDIRECT_URI'].includes(name) ? v : undefined,
    };
  };
  return NextResponse.json({
    DATABASE_URL: info('DATABASE_URL'), REDIS_URL: info('REDIS_URL'),
    GOOGLE_CLIENT_ID: info('GOOGLE_CLIENT_ID'), GOOGLE_CLIENT_SECRET: info('GOOGLE_CLIENT_SECRET'),
    GOOGLE_REDIRECT_URI: info('GOOGLE_REDIRECT_URI'), TOKEN_ENCRYPTION_KEY: info('TOKEN_ENCRYPTION_KEY'),
    SESSION_SECRET: info('SESSION_SECRET'), APP_URL: info('APP_URL'),
    NODE_ENV: process.env.NODE_ENV,
  });
}
EOF

# oauth start
cat > app/api/oauth/google/start/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { oauthClient } from '@/lib/gmail';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const senderEmail = url.searchParams.get('email') ?? '';
    const c = oauthClient();
    const auth = c.generateAuthUrl({ access_type: 'offline', prompt: 'consent', scope: ['https://www.googleapis.com/auth/gmail.send','https://www.googleapis.com/auth/userinfo.email'], state: senderEmail });
    return NextResponse.redirect(auth);
  } catch (err: any) {
    return NextResponse.json({ error: 'OAuth start failed', message: err?.message ?? String(err), hint: 'Check GOOGLE_CLIENT_ID/SECRET/REDIRECT_URI' }, { status: 500 });
  }
}
EOF

# oauth callback
cat > app/api/oauth/google/callback/route.ts <<'EOF'
import { NextResponse } from 'next/server';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const appUrl = process.env.APP_URL || 'https://emailcampaign-ten.vercel.app';
  if (error) return NextResponse.json({ error: 'Google error', detail: error }, { status: 400 });
  if (!code) return NextResponse.json({ error: 'Missing code' }, { status: 400 });
  const env = { GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI: process.env.GOOGLE_REDIRECT_URI, TOKEN_ENCRYPTION_KEY: process.env.TOKEN_ENCRYPTION_KEY, DATABASE_URL: process.env.DATABASE_URL };
  const missing = Object.entries(env).filter(([, v]) => !v).map(([k]) => k);
  if (missing.length) return NextResponse.json({ error: 'Missing env vars', missing }, { status: 500 });
  if (!/^[0-9a-fA-F]{64}$/.test(env.TOKEN_ENCRYPTION_KEY!)) return NextResponse.json({ error: 'TOKEN_ENCRYPTION_KEY invalid', detail: `Expected 64 hex, got ${env.TOKEN_ENCRYPTION_KEY!.length}` }, { status: 500 });
  try {
    const { oauthClient } = await import('@/lib/gmail');
    const { prisma } = await import('@/lib/prisma');
    const { encrypt } = await import('@/lib/crypto');
    const { google } = await import('googleapis');
    const c = oauthClient();
    const { tokens } = await c.getToken(code);
    c.setCredentials(tokens);
    const oauth2 = google.oauth2({ version: 'v2', auth: c });
    const me = await oauth2.userinfo.get();
    const email = me.data.email;
    if (!email) throw new Error('Could not get email');
    await prisma.senderAccount.upsert({
      where: { email },
      create: { email, displayName: me.data.name ?? email, accessToken: tokens.access_token ? encrypt(tokens.access_token) : null, refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : null, tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : null, scope: tokens.scope, status: 'CONNECTED', warmupStartedAt: new Date() },
      update: { accessToken: tokens.access_token ? encrypt(tokens.access_token) : undefined, refreshToken: tokens.refresh_token ? encrypt(tokens.refresh_token) : undefined, tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : undefined, status: 'CONNECTED' },
    });
    return NextResponse.redirect(`${appUrl}/senders?connected=${encodeURIComponent(email)}`);
  } catch (err: any) {
    console.error('[oauth/callback]', err);
    return NextResponse.json({ error: 'OAuth callback failed', message: err?.message ?? String(err) }, { status: 500 });
  }
}
EOF

# test email
cat > app/api/test-email/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { gmailFor } from '@/lib/gmail';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate } from '@/lib/personalization';
import { checkEmail } from '@/lib/spam-checker';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function POST(req: Request) {
  const { to, subject, html } = await req.json();
  if (!to || !subject || !html) return NextResponse.json({ error: 'Missing fields' }, { status: 400 });
  const spam = checkEmail({ subject, html, fromEmail: to });
  if (spam.blocked) return NextResponse.json({ error: 'Spam score too high', score: spam.score, issues: spam.issues }, { status: 400 });
  const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
  if (!sender || !sender.refreshToken) return NextResponse.json({ error: 'No connected sender' }, { status: 400 });
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken);
  const gmail = gmailFor(access, refresh);
  const body = renderTemplate(html, { name: 'Test', email: to, company: 'Acme', city: '', phone: '' });
  const raw = buildMime({ from: `${sender.displayName ?? sender.email} <${sender.email}>`, to, subject, html: body, text: htmlToText(body) });
  const res = await gmail.users.messages.send({ userId: 'me', requestBody: { raw: Buffer.from(raw).toString('base64url') } });
  return NextResponse.json({ ok: true, id: res.data.id, spamScore: spam.score });
}
EOF

# unsubscribe
cat > 'app/api/unsubscribe/[token]/route.ts' <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export async function GET(_: Request, { params }: { params: { token: string } }) {
  const email = Buffer.from(params.token, 'base64url').toString();
  if (!email) return NextResponse.json({ error: 'Invalid' }, { status: 400 });
  await prisma.suppressionList.upsert({ where: { email }, create: { email, reason: 'UNSUBSCRIBED' }, update: { reason: 'UNSUBSCRIBED' } });
  return new NextResponse(`<html><body style="font-family:sans-serif;padding:40px;text-align:center"><h1>✅ Unsubscribed</h1><p>${email}</p></body></html>`, { headers: { 'Content-Type': 'text/html' } });
}
EOF

echo "✅ All API routes ready"

# ---------- 10. Dedupe runtime/dynamic ----------
node <<'NODEEOF'
const fs = require('fs');
const path = require('path');
function walk(dir, out=[]) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name === 'route.ts') out.push(p);
  }
  return out;
}
const files = walk('app/api');
const RE = /^\s*export\s+const\s+(dynamic|runtime)\s*=/;
let fixed = 0;
for (const f of files) {
  const orig = fs.readFileSync(f, 'utf8');
  let lines = orig.split('\n').filter(l => !RE.test(l));
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) if (/^\s*import\s/.test(lines[i])) lastImport = i;
  const ins = ['', 'export const dynamic = "force-dynamic";', 'export const runtime = "nodejs";', ''];
  if (lastImport >= 0) lines.splice(lastImport + 1, 0, ...ins);
  else lines.unshift(...ins);
  const out = lines.join('\n').replace(/\n{3,}/g, '\n\n');
  if (out !== orig) { fs.writeFileSync(f, out); fixed++; }
}
console.log('   Deduped: ' + fixed + '/' + files.length);
NODEEOF

# ---------- 11. Middleware ----------
cat > middleware.ts <<'EOF'
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
export function middleware(req: NextRequest) {
  const token = req.cookies.get('ec_session')?.value;
  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', req.nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}
export const config = { matcher: ['/dashboard/:path*','/senders/:path*','/history/:path*','/campaigns/:path*','/anti-spam/:path*'] };
EOF
sed -i 's/\r$//' middleware.ts

# ---------- 12. globals.css ----------
cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
:root{--bg:#05060a;--fg:#f5f7fa}
*{-webkit-tap-highlight-color:transparent}
html,body{background:var(--bg);color:var(--fg);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",Inter,sans-serif;-webkit-font-smoothing:antialiased;overflow-x:hidden;scroll-behavior:smooth}
.card{@apply bg-slate-900/60 backdrop-blur border border-slate-800/60 rounded-2xl p-6}
.btn{@apply inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-medium transition-all duration-300 select-none}
.btn-primary{@apply bg-white text-black hover:bg-slate-200 shadow-lg shadow-white/10}
.btn-ghost{@apply bg-white/5 hover:bg-white/10 text-white border border-white/10 backdrop-blur}
.btn-danger{@apply bg-red-500/90 hover:bg-red-500 text-white}
.input{@apply w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-white/30 focus:bg-white/[0.07] transition-all duration-200}
.gradient-text{background:linear-gradient(120deg,#a78bfa 0%,#60a5fa 30%,#34d399 60%,#f472b6 100%);background-size:300% 300%;-webkit-background-clip:text;background-clip:text;color:transparent;animation:gradientShift 8s ease infinite}
@keyframes gradientShift{0%,100%{background-position:0% 50%}50%{background-position:100% 50%}}
.aurora{position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:0}
.aurora::before,.aurora::after{content:'';position:absolute;width:60vw;height:60vw;border-radius:50%;filter:blur(120px);opacity:.35}
.aurora::before{background:radial-gradient(circle,#6366f1,transparent 65%);top:-20%;left:-10%;animation:float1 18s ease-in-out infinite}
.aurora::after{background:radial-gradient(circle,#ec4899,transparent 65%);bottom:-30%;right:-10%;animation:float2 22s ease-in-out infinite}
@keyframes float1{0%,100%{transform:translate3d(0,0,0) scale(1)}50%{transform:translate3d(8vw,6vh,0) scale(1.15)}}
@keyframes float2{0%,100%{transform:translate3d(0,0,0) scale(1.1)}50%{transform:translate3d(-10vw,-8vh,0) scale(.95)}}
@keyframes fadeInUp{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
.animate-in{animation:fadeInUp .9s cubic-bezier(.22,1,.36,1) both}
.animate-in-slow{animation:fadeInUp 1.3s cubic-bezier(.22,1,.36,1) both}
.animate-fade{animation:fadeIn 1.4s ease both}
.delay-1{animation-delay:.15s}.delay-2{animation-delay:.30s}.delay-3{animation-delay:.45s}.delay-4{animation-delay:.60s}.delay-5{animation-delay:.75s}
.glass-nav{background:rgba(5,6,10,.6);backdrop-filter:saturate(180%) blur(18px);-webkit-backdrop-filter:saturate(180%) blur(18px);border-bottom:1px solid rgba(255,255,255,.06)}
.tilt{transition:transform .5s cubic-bezier(.22,1,.36,1),box-shadow .5s ease;transform-style:preserve-3d;will-change:transform}
.tilt:hover{transform:perspective(1200px) rotateX(4deg) rotateY(-4deg) translateY(-6px) scale(1.02);box-shadow:0 30px 60px -20px rgba(99,102,241,.35),0 0 0 1px rgba(255,255,255,.05)}
.shimmer{position:relative;overflow:hidden}
.shimmer::after{content:'';position:absolute;inset:0;background:linear-gradient(115deg,transparent 30%,rgba(255,255,255,.35) 50%,transparent 70%);transform:translateX(-100%);animation:shimmer 3s ease-in-out infinite}
@keyframes shimmer{0%{transform:translateX(-100%)}60%,100%{transform:translateX(100%)}}
@keyframes floaty{0%,100%{transform:translateY(0)}50%{transform:translateY(-12px)}}
.floaty{animation:floaty 6s ease-in-out infinite}
::-webkit-scrollbar{width:8px;height:8px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:rgba(255,255,255,.12);border-radius:8px}::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.22)}
EOF
sed -i 's/\r$//' app/globals.css

# ---------- 13. Layout + Pages ----------
cat > app/layout.tsx <<'EOF'
import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'EmailCampaign', description: 'Modern email campaign platform.' };
export default function Root({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="min-h-screen antialiased">{children}</body></html>;
}
EOF
sed -i 's/\r$//' app/layout.tsx

# landing
cat > app/page.tsx <<'EOF'
import Link from 'next/link';
export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      <div className="aurora" aria-hidden />
      <nav className="glass-nav fixed top-0 inset-x-0 z-50">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-pink-500 group-hover:scale-110 transition" />
            <span className="font-semibold tracking-tight">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm text-slate-300 hover:text-white transition">Sign in</Link>
            <Link href="/login" className="btn btn-primary text-sm">Get started</Link>
          </div>
        </div>
      </nav>
      <section className="relative pt-40 pb-32 px-6">
        <div className="max-w-5xl mx-auto text-center relative z-10">
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-[1.02] animate-in-slow">
            Send email<br /><span className="gradient-text">that feels personal.</span>
          </h1>
          <p className="mt-8 text-lg md:text-xl text-slate-400 max-w-2xl mx-auto leading-relaxed animate-in-slow delay-2">
            Production-ready campaign platform. Import contacts, paste HTML, hit send.
          </p>
          <div className="mt-12 flex flex-wrap items-center justify-center gap-4 animate-in-slow delay-3">
            <Link href="/login" className="btn btn-primary text-base px-7 py-3">Start free →</Link>
          </div>
        </div>
      </section>
      <footer className="relative border-t border-white/5 py-10 px-6 text-sm text-slate-500">
        <div className="max-w-6xl mx-auto text-center">© {new Date().getFullYear()} EmailCampaign</div>
      </footer>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/page.tsx

# login
mkdir -p app/login
cat > app/login/page.tsx <<'EOF'
'use client';
import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const submit = async (e: React.FormEvent) => {
    e.preventDefault(); setErr(''); setBusy(true);
    try {
      const r = await fetch('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, name }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next); router.refresh();
    } catch (e: any) { setErr(e.message); setBusy(false); }
  };
  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />
      <div className="relative z-10 w-full max-w-md">
        <Link href="/" className="inline-flex items-center gap-2 mb-8 text-sm text-slate-400 hover:text-white transition">← Back</Link>
        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty" />
            <h1 className="text-2xl font-semibold tracking-tight">Welcome back</h1>
          </div>
          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Email</label>
              <input type="email" required value={email} onChange={e => setEmail(e.target.value)} className="input" />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Name (optional)</label>
              <input type="text" value={name} onChange={e => setName(e.target.value)} className="input" />
            </div>
            {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">{err}</div>}
            <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">{busy ? 'Signing in…' : 'Continue →'}</button>
          </form>
        </div>
      </div>
    </div>
  );
}
export default function LoginPage() {
  return <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}><LoginInner /></Suspense>;
}
EOF
sed -i 's/\r$//' app/login/page.tsx

# dashboard layout
mkdir -p app/dashboard
cat > app/dashboard/layout.tsx <<'EOF'
import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { verifySession } from '@/lib/session';
import LogoutButton from './logout-button';
export const dynamic = 'force-dynamic';
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session) redirect('/login');
  return (
    <div className="min-h-screen">
      <nav className="glass-nav sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-6 py-3 flex items-center justify-between">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
            <span className="font-semibold tracking-tight text-sm">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-1">
            <Link href="/dashboard" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Campaign</Link>
            <Link href="/senders" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Senders</Link>
            <Link href="/senders/rotation" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Rotation</Link>
            <Link href="/anti-spam" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">🛡️ Anti-Spam</Link>
            <Link href="/history" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">History</Link>
            <div className="w-px h-5 bg-white/10 mx-2" />
            <span className="text-xs text-slate-500 hidden md:inline">{session.email}</span>
            <LogoutButton />
          </div>
        </div>
      </nav>
      <main className="max-w-6xl mx-auto px-6 py-8">{children}</main>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/layout.tsx

cat > app/dashboard/logout-button.tsx <<'EOF'
'use client';
import { useRouter } from 'next/navigation';
export default function LogoutButton() {
  const router = useRouter();
  return <button onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); router.push('/'); router.refresh(); }} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Sign out</button>;
}
EOF
sed -i 's/\r$//' app/dashboard/logout-button.tsx

# dashboard page
cat > app/dashboard/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
export default function DashboardHome() {
  const [senders, setSenders] = useState<any[]>([]);
  useEffect(() => { fetch('/api/senders').then(r => r.ok ? r.json() : []).then(setSenders).catch(() => {}); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">📧 Campaign Dashboard</h1>
      <p className="text-slate-400">Import contacts, paste HTML, launch your campaign.</p>
      <div className="grid md:grid-cols-4 gap-4">
        <a href="/senders" className="tilt card"><div className="text-3xl mb-2">🔐</div><h3 className="font-semibold">Senders</h3><p className="text-sm text-slate-400 mt-1">{senders.length} connected</p></a>
        <a href="/senders/rotation" className="tilt card"><div className="text-3xl mb-2">🔄</div><h3 className="font-semibold">Rotation</h3><p className="text-sm text-slate-400 mt-1">Batch settings</p></a>
        <a href="/anti-spam" className="tilt card"><div className="text-3xl mb-2">🛡️</div><h3 className="font-semibold">Anti-Spam</h3><p className="text-sm text-slate-400 mt-1">7-layer protection</p></a>
        <a href="/history" className="tilt card"><div className="text-3xl mb-2">📊</div><h3 className="font-semibold">History</h3><p className="text-sm text-slate-400 mt-1">Past campaigns</p></a>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/dashboard/page.tsx

# senders
mkdir -p app/senders
cat > app/senders/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
export default function SendersPage() {
  const [list, setList] = useState<any[]>([]);
  const [email, setEmail] = useState('');
  const [msg, setMsg] = useState('');
  const load = () => fetch('/api/senders').then(r => r.json()).then(setList);
  useEffect(() => { load(); }, []);
  const connect = () => { window.location.href = '/api/oauth/google/start?email=' + encodeURIComponent(email); };
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">🔐 Manage Senders</h1>
      {msg && <div className="card text-sm text-green-400">{msg}</div>}
      <div className="card">
        <h2 className="font-semibold mb-2">Connect Gmail / Workspace</h2>
        <div className="flex gap-3 flex-wrap">
          <input className="input max-w-xs" placeholder="sales01@company.com" value={email} onChange={e => setEmail(e.target.value)} />
          <button className="btn btn-primary" onClick={connect} disabled={!email}>Connect Google</button>
        </div>
      </div>
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">Email</th><th className="p-3">Status</th><th className="p-3">Sent Today</th><th className="p-3">Last Success</th></tr>
          </thead>
          <tbody>
            {list.map(s => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3">{s.email}</td>
                <td className="p-3"><span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>{s.status}</span></td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3 text-xs text-slate-500">{s.lastSuccessAt ? new Date(s.lastSuccessAt).toLocaleString() : '—'}</td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={4} className="p-8 text-center text-slate-500">No senders.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/senders/page.tsx

# rotation
mkdir -p app/senders/rotation
cat > app/senders/rotation/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
export default function RotationPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const load = async () => { const r = await fetch('/api/senders/rotation'); const j = await r.json(); setSenders(j.senders ?? []); };
  useEffect(() => { load(); const iv = setInterval(load, 5000); return () => clearInterval(iv); }, []);
  const update = async (id: string, patch: any) => { setBusy(true); await fetch('/api/senders/rotation', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id, ...patch }) }); await load(); setBusy(false); setMsg('✅ Saved'); setTimeout(() => setMsg(''), 2000); };
  const resetAll = async () => { if (!confirm('Reset all daily counters?')) return; setBusy(true); await fetch('/api/senders/rotation', { method: 'PUT' }); await load(); setBusy(false); setMsg('✅ Reset'); setTimeout(() => setMsg(''), 2000); };
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div><h1 className="text-3xl font-semibold tracking-tight">🔄 Sender Rotation</h1><p className="text-sm text-slate-400 mt-1">Round-robin: each sender sends N emails, then next.</p></div>
        <div className="flex gap-2">
          <button onClick={resetAll} className="btn btn-ghost text-sm" disabled={busy}>Reset Counters</button>
          <Link href="/senders" className="btn btn-ghost text-sm">← Senders</Link>
        </div>
      </div>
      {msg && <div className="card text-sm text-green-400">{msg}</div>}
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">#</th><th className="p-3">Sender</th><th className="p-3">Status</th><th className="p-3">Active</th><th className="p-3">Sent Today</th><th className="p-3">Batch</th><th className="p-3">Limit</th><th className="p-3">Warmup</th><th className="p-3">Reputation</th></tr>
          </thead>
          <tbody>
            {senders.map((s, i) => (
              <tr key={s.id} className="border-t border-white/5">
                <td className="p-3 text-slate-500">{i + 1}</td>
                <td className="p-3"><div className="font-medium text-xs">{s.email}</div></td>
                <td className="p-3"><span className={s.status === 'CONNECTED' ? 'text-green-400' : 'text-red-400'}>{s.status}</span></td>
                <td className="p-3"><input type="checkbox" checked={s.isActive} onChange={e => update(s.id, { isActive: e.target.checked })} /></td>
                <td className="p-3">{s.sentToday}</td>
                <td className="p-3">{s.batchCount} / {s.dailyLimit}</td>
                <td className="p-3"><input type="number" value={s.dailyLimit} onChange={e => update(s.id, { dailyLimit: parseInt(e.target.value) || 10 })} className="w-16 bg-white/5 border border-white/10 rounded px-2 py-1 text-xs" /></td>
                <td className="p-3">{s.warmupEnabled ? <span className="text-xs px-2 py-0.5 rounded bg-blue-500/20 text-blue-300">Day {s.warmupDay}</span> : <span className="text-xs text-slate-500">off</span>}</td>
                <td className="p-3"><div className="w-16 h-1.5 bg-white/10 rounded-full overflow-hidden"><div className={s.reputationScore >= 80 ? 'bg-green-500 h-full' : s.reputationScore >= 50 ? 'bg-amber-500 h-full' : 'bg-red-500 h-full'} style={{ width: `${s.reputationScore}%` }} /></div></td>
              </tr>
            ))}
            {senders.length === 0 && <tr><td colSpan={9} className="p-8 text-center text-slate-500">No senders. <Link href="/senders" className="text-blue-400 underline">Add one</Link></td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/senders/rotation/page.tsx

# anti-spam
mkdir -p app/anti-spam
cat > app/anti-spam/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
export default function AntiSpamPage() {
  const [senders, setSenders] = useState<any[]>([]);
  const [report, setReport] = useState<any>(null);
  const [subject, setSubject] = useState('Hello from our team');
  const [html, setHtml] = useState('<h1>Hi there</h1><p>We have an update.</p><p><a href="https://example.com/unsubscribe">Unsubscribe</a></p>');
  const [checking, setChecking] = useState(false);
  useEffect(() => { fetch('/api/senders/rotation').then(r => r.json()).then(j => setSenders(j.senders ?? [])).catch(() => {}); }, []);
  const runCheck = async () => {
    setChecking(true);
    const r = await fetch('/api/anti-spam/check', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ subject, html, fromEmail: senders[0]?.email }) });
    setReport(await r.json());
    setChecking(false);
  };
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-semibold tracking-tight">🛡️ Anti-Spam</h1><p className="text-sm text-slate-400 mt-1">7-layer protection</p></div>
        <Link href="/senders" className="btn btn-ghost text-sm">← Senders</Link>
      </div>
      <div className="grid md:grid-cols-4 gap-3">
        {[['📊','Spam Checker','Pre-send analysis'],['🔥','Warm-up','5→10→25→50/day'],['🧹','Hygiene','Disposable filter'],['📉','Bounce','Auto-suppress']].map(([i,t,d]) => (
          <div key={t} className="card !p-4"><div className="text-2xl mb-1">{i}</div><div className="font-semibold text-sm">{t}</div><div className="text-xs text-slate-400 mt-1">{d}</div></div>
        ))}
      </div>
      <div className="card">
        <h2 className="font-semibold mb-3">📊 Content Spam Checker</h2>
        <p className="text-xs text-slate-400 mb-4">Score &lt;30 = safe, 30-49 = warning, 50+ = blocked.</p>
        <input className="input mb-2" value={subject} onChange={e => setSubject(e.target.value)} placeholder="Subject" />
        <textarea className="input font-mono text-xs mb-3" rows={8} value={html} onChange={e => setHtml(e.target.value)} />
        <button onClick={runCheck} disabled={checking} className="btn btn-primary">{checking ? 'Checking…' : 'Run Check'}</button>
        {report && (
          <div className="mt-4 border-t border-white/10 pt-4">
            <div className="flex items-center gap-4 mb-3">
              <div className={`text-4xl font-bold ${report.blocked ? 'text-red-400' : report.warning ? 'text-amber-400' : 'text-green-400'}`}>{report.score}</div>
              <div><div className="font-semibold">{report.blocked ? '🚫 BLOCKED' : report.warning ? '⚠️ Warning' : '✅ Safe'}</div></div>
            </div>
            {report.issues?.map((iss: any, i: number) => (
              <div key={i} className={`text-xs px-3 py-2 rounded-lg border mb-2 ${iss.severity === 'high' ? 'bg-red-500/10 border-red-500/20 text-red-300' : iss.severity === 'medium' ? 'bg-amber-500/10 border-amber-500/20 text-amber-300' : 'bg-slate-500/10 border-slate-500/20 text-slate-400'}`}>
                <b>{iss.category}:</b> {iss.message} <span className="opacity-60">(+{iss.points})</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/anti-spam/page.tsx

# history
mkdir -p app/history
cat > app/history/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';
export default function History() {
  const [list, setList] = useState<any[]>([]);
  useEffect(() => { fetch('/api/campaigns').then(r => r.json()).then(setList); }, []);
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-semibold tracking-tight">📊 Campaign History</h1>
      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr><th className="p-3">Campaign</th><th className="p-3">Total</th><th className="p-3">Sent</th><th className="p-3">Failed</th><th className="p-3">Spam</th><th className="p-3">Status</th><th className="p-3">Created</th><th className="p-3"></th></tr>
          </thead>
          <tbody>
            {list.map(c => (
              <tr key={c.id} className="border-t border-white/5">
                <td className="p-3">{c.name}</td><td className="p-3">{c.totalCount}</td><td className="p-3">{c.sentCount}</td><td className="p-3">{c.failedCount}</td><td className="p-3">{c.spamScore ?? '—'}</td><td className="p-3">{c.status}</td>
                <td className="p-3 text-xs text-slate-500">{new Date(c.createdAt).toLocaleString()}</td>
                <td className="p-3"><a className="text-blue-400 underline" href={'/campaigns/' + c.id}>Open</a></td>
              </tr>
            ))}
            {list.length === 0 && <tr><td colSpan={8} className="p-8 text-center text-slate-500">No campaigns.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' app/history/page.tsx

# campaign live (RECIPIENT STATUS)
mkdir -p 'app/campaigns/[id]'
cat > 'app/campaigns/[id]/page.tsx' <<'EOF'
'use client';
import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
export default function CampaignLive() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [s, setS] = useState<any>(null);
  const [recipients, setRecipients] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');
  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${id}/status`).then(r => r.json()).then(j => setS({ ...j.counts, status: j.campaign.status, ts: j.updatedAt }));
    load();
    const iv = setInterval(load, 2000);
    return () => clearInterval(iv);
  }, [id]);
  useEffect(() => {
    const load = () => fetch(`/api/campaigns/${id}/recipients?status=${filter}`).then(r => r.json()).then(setRecipients);
    load();
    const iv = setInterval(load, 3000);
    return () => clearInterval(iv);
  }, [id, filter]);
  const act = async (a: 'pause'|'resume'|'stop') => {
    if (a === 'stop' && !confirm('Stop campaign?')) return;
    await fetch(`/api/campaigns/${id}/${a}`, { method: 'POST' });
  };
  const progress = s?.progress ?? 0;
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 flex-wrap">
        <h1 className="text-2xl font-bold">Status: {s?.status ?? '...'}</h1>
        <span className="text-xs px-2 py-1 rounded bg-slate-800">LIVE</span>
        <div className="flex gap-2 ml-auto">
          {s?.status === 'RUNNING' && <button className="btn btn-ghost" onClick={() => act('pause')}>PAUSE</button>}
          {s?.status === 'PAUSED' && <button className="btn btn-primary" onClick={() => act('resume')}>RESUME</button>}
          {s?.status !== 'COMPLETED' && s?.status !== 'STOPPED' && <button className="btn btn-danger" onClick={() => act('stop')}>STOP</button>}
        </div>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        {[['TOTAL',s?.total,''],['SENT',s?.sent,'text-blue-400'],['DELIVERED',s?.delivered,'text-green-400'],['FAILED',s?.failed,'text-red-400'],['BOUNCED',s?.bounced,'text-orange-400'],['PENDING',s?.pending,'text-yellow-400'],['SUPPRESSED',s?.suppressed,'text-slate-400']].map(([l,v,c]) => (
          <div key={l as string} className="bg-slate-950 border border-slate-800 rounded-lg p-3">
            <div className="text-[10px] uppercase text-slate-400">{l}</div>
            <div className={`text-xl font-bold ${c}`}>{(v ?? 0).toLocaleString()}</div>
          </div>
        ))}
      </div>
      <div className="card">
        <div className="flex justify-between text-sm mb-2"><span>Progress</span><b>{progress}%</b></div>
        <div className="w-full h-3 bg-slate-800 rounded overflow-hidden"><div className="h-full bg-blue-500 transition-all" style={{ width: progress + '%' }} /></div>
      </div>
      <div className="card">
        <div className="flex gap-2 flex-wrap mb-3">
          {['ALL','QUEUED','PROCESSING','SENT','DELIVERED','FAILED','BOUNCED','SUPPRESSED'].map(f => (
            <button key={f} onClick={() => setFilter(f)} className={'text-xs px-3 py-1 rounded ' + (filter === f ? 'bg-blue-600' : 'bg-slate-800 hover:bg-slate-700')}>{f}</button>
          ))}
        </div>
        <div className="max-h-96 overflow-auto">
          <table className="w-full text-xs">
            <thead className="text-slate-400 text-left sticky top-0 bg-slate-900"><tr><th className="p-2">Email</th><th>Name</th><th>Status</th><th>Error</th></tr></thead>
            <tbody>
              {recipients.map(r => (
                <tr key={r.id} className="border-t border-slate-800">
                  <td className="p-2">{r.email}</td><td>{r.name}</td>
                  <td className={r.status === 'DELIVERED' ? 'text-green-400' : r.status === 'SENT' ? 'text-blue-400' : r.status === 'FAILED' || r.status === 'BOUNCED' ? 'text-red-400' : r.status === 'SUPPRESSED' ? 'text-slate-500' : 'text-yellow-400'}>{r.status}</td>
                  <td className="text-slate-500 truncate max-w-xs">{r.error ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
EOF
sed -i 's/\r$//' 'app/campaigns/[id]/page.tsx'

echo "✅ All pages ready"

# ---------- 14. Prisma validate + verify ----------
echo ""
echo "🔎 Verification..."

if head -3 prisma/schema.prisma | grep -q "^generator client {"; then echo "   ✅ Prisma schema OK"; else echo "   ❌ Prisma schema WRONG"; exit 1; fi

BAD=0
for f in $(find app/api -name "route.ts" 2>/dev/null); do
  R=$(grep -c "^export const runtime" "$f" 2>/dev/null | tr -d '[:space:]')
  D=$(grep -c "^export const dynamic" "$f" 2>/dev/null | tr -d '[:space:]')
  [ "$R" -ne 1 ] || [ "$D" -ne 1 ] && BAD=$((BAD+1))
done
[ $BAD -eq 0 ] && echo "   ✅ All routes clean" || echo "   ⚠️ $BAD issues"

for f in lib/redis.ts lib/queue.ts lib/crypto.ts lib/gmail.ts lib/spam-checker.ts lib/sender-rotation.ts lib/warmup.ts workers/sender.worker.ts app/anti-spam/page.tsx app/senders/rotation/page.tsx app/dashboard/layout.tsx middleware.ts; do
  [ -f "$f" ] && echo "   ✅ $f" || echo "   ❌ MISSING $f"
done

# ---------- 15. Git ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git ls-files --error-unmatch .env >/dev/null 2>&1 && git rm --cached .env >/dev/null 2>&1 || true
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Final: domain fix + recipient status + all features"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ FINAL MASTER COMPLETE"
echo "==================================================="
echo ""
echo "🌐 Domain: https://emailcampaign-ten.vercel.app"
echo ""
echo "🎯 Deploy ke baad (2-3 min) ye URLs check karo:"
echo ""
echo "  1. Health:      https://emailcampaign-ten.vercel.app/api/health"
echo "  2. Queue:       https://emailcampaign-ten.vercel.app/api/queue/health"
echo "  3. Debug Env:   https://emailcampaign-ten.vercel.app/api/debug/env"
echo ""
echo "📊 Campaign launch ke baad:"
echo "  - Live counters (TOTAL, SENT, PENDING, etc.)"
echo "  - Recipient table (kisko sent, kisko pending)"
echo "  - Filter by status (ALL/SENT/PENDING/FAILED)"
echo ""
echo "⚠️  Vercel me ye env vars check karo:"
echo "  APP_URL = https://emailcampaign-ten.vercel.app"
echo "  GOOGLE_REDIRECT_URI = https://emailcampaign-ten.vercel.app/api/oauth/google/callback"
echo ""
echo "==================================================="