#!/usr/bin/env bash
set -e

echo "==================================================="
echo " 🔐 Username + Password Auth System"
echo "==================================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"

# ---------- 1. CRLF ----------
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.sh" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./.git/*" \
  -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ---------- 2. Password lib ----------
echo ""
echo "📝 lib/password.ts..."
mkdir -p lib
cat > lib/password.ts <<'EOF'
import crypto from 'crypto';

/**
 * Password hashing with Node's built-in scrypt (no external deps).
 * Format: scrypt$N$salt$hash
 */

const N = 16384;      // CPU/memory cost
const KEYLEN = 64;

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, KEYLEN, { N });
  return `scrypt$${N}$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  try {
    const [scheme, nStr, saltHex, hashHex] = stored.split('$');
    if (scheme !== 'scrypt') return false;
    const N = parseInt(nStr, 10);
    const salt = Buffer.from(saltHex, 'hex');
    const expected = Buffer.from(hashHex, 'hex');
    const actual = crypto.scryptSync(password, salt, expected.length, { N });
    return crypto.timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

export function generateRandomPassword(len = 16): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
  let out = '';
  const buf = crypto.randomBytes(len);
  for (let i = 0; i < len; i++) out += chars[buf[i] % chars.length];
  return out;
}
EOF

# ---------- 3. Update Prisma User model ----------
echo ""
echo "📝 Updating prisma/schema.prisma..."

# Check if User has username field
if ! grep -q "username.*String.*@unique" prisma/schema.prisma 2>/dev/null; then
  # Replace User model
  node <<'NODEEOF'
const fs = require('fs');
let s = fs.readFileSync('prisma/schema.prisma', 'utf8');

// Remove old User model
s = s.replace(/model User \{[\s\S]*?\n\}/, '');

// Add new User model with username/password
s = s.replace(
  /(model SenderAccount \{)/,
  `model User {
  id           String   @id @default(cuid())
  username     String   @unique
  passwordHash String
  displayName  String?
  role         String   @default("member")
  isActive     Boolean  @default(true)
  lastLoginAt  DateTime?
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}

$1`
);

fs.writeFileSync('prisma/schema.prisma', s);
console.log('   ✅ User model updated');
NODEEOF
  sed -i 's/\r$//' prisma/schema.prisma
fi

# ---------- 4. Session lib ----------
echo "📝 lib/session.ts..."
cat > lib/session.ts <<'EOF'
import crypto from 'crypto';

const SECRET = process.env.SESSION_SECRET || 'dev-secret-change-me';

export type SessionPayload = {
  userId: string;
  username: string;
  role: string;
  ts: number;
};

export function signSession(payload: SessionPayload): string {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function verifySession(token?: string): SessionPayload | null {
  if (!token) return null;
  const [data, sig] = token.split('.');
  if (!data || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (sig !== expected) return null;
  try {
    const p = JSON.parse(Buffer.from(data, 'base64url').toString());
    // 30 day expiry
    if (Date.now() - p.ts > 30 * 24 * 60 * 60 * 1000) return null;
    return p;
  } catch {
    return null;
  }
}
EOF

# ---------- 5. Login API (username + password) ----------
echo "📝 app/api/auth/login/route.ts..."
mkdir -p app/api/auth/login
cat > app/api/auth/login/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyPassword } from '@/lib/password';
import { signSession } from '@/lib/session';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const { username, password } = await req.json();

  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }

  const cleanUsername = String(username).trim().toLowerCase();

  const user = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (!user || !user.isActive) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  if (!verifyPassword(password, user.passwordHash)) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() },
  });

  const token = signSession({
    userId: user.id,
    username: user.username,
    role: user.role,
    ts: Date.now(),
  });

  const res = NextResponse.json({
    ok: true,
    user: { username: user.username, role: user.role },
  });
  res.cookies.set('ec_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}
EOF

# ---------- 6. Auth me ----------
echo "📝 app/api/auth/me/route.ts..."
mkdir -p app/api/auth/me
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
  return NextResponse.json({
    user: { username: user.username, role: user.role },
  });
}
EOF

# ---------- 7. Team management API ----------
echo "📝 app/api/team/route.ts..."
mkdir -p app/api/team
cat > app/api/team/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { verifySession } from '@/lib/session';
import { hashPassword, generateRandomPassword } from '@/lib/password';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

async function requireAdmin() {
  const token = cookies().get('ec_session')?.value;
  const session = verifySession(token);
  if (!session || session.role !== 'owner') return null;
  return session;
}

// GET: list team members
export async function GET() {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: {
      id: true, username: true, displayName: true,
      role: true, isActive: true, lastLoginAt: true, createdAt: true,
    },
  });
  return NextResponse.json({ members: users });
}

// POST: add new member
export async function POST(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { username, password, displayName, role } = await req.json();
  if (!username || username.length < 3) {
    return NextResponse.json({ error: 'Username must be at least 3 characters' }, { status: 400 });
  }
  const cleanUsername = String(username).trim().toLowerCase();

  const finalPassword = password && password.length >= 6
    ? password
    : generateRandomPassword(14);

  const exists = await prisma.user.findUnique({ where: { username: cleanUsername } });
  if (exists) return NextResponse.json({ error: 'Username already exists' }, { status: 400 });

  const user = await prisma.user.create({
    data: {
      username: cleanUsername,
      passwordHash: hashPassword(finalPassword),
      displayName: displayName || cleanUsername,
      role: role === 'owner' ? 'owner' : 'member',
    },
  });

  return NextResponse.json({
    ok: true,
    user: { id: user.id, username: user.username, role: user.role },
    password: finalPassword, // Show once to admin
  });
}

// PATCH: update member (reset password, toggle active, change role)
export async function PATCH(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id, action, newPassword, role, isActive } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const data: any = {};
  if (action === 'reset-password') {
    const pwd = newPassword && newPassword.length >= 6 ? newPassword : generateRandomPassword(14);
    data.passwordHash = hashPassword(pwd);
    await prisma.user.update({ where: { id }, data });
    return NextResponse.json({ ok: true, password: pwd });
  }
  if (typeof role === 'string') data.role = role === 'owner' ? 'owner' : 'member';
  if (typeof isActive === 'boolean') data.isActive = isActive;

  await prisma.user.update({ where: { id }, data });
  return NextResponse.json({ ok: true });
}

// DELETE: remove member
export async function DELETE(req: Request) {
  const session = await requireAdmin();
  if (!session) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id } = await req.json();
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  // Prevent deleting self
  if (id === session.userId) {
    return NextResponse.json({ error: 'Cannot delete yourself' }, { status: 400 });
  }

  await prisma.user.delete({ where: { id } });
  return NextResponse.json({ ok: true });
}
EOF

# ---------- 8. Setup admin endpoint ----------
echo "📝 app/api/auth/setup/route.ts (one-time admin creation)..."
mkdir -p app/api/auth/setup
cat > app/api/auth/setup/route.ts <<'EOF'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { hashPassword } from '@/lib/password';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * One-time admin creation.
 * Call with POST body: { username, password, setupKey }
 * setupKey must match env var ADMIN_SETUP_KEY
 * Only works if NO users exist yet.
 */
export async function POST(req: Request) {
  const { username, password, setupKey } = await req.json();

  const expectedKey = process.env.ADMIN_SETUP_KEY || '';
  if (!expectedKey) {
    return NextResponse.json({ error: 'ADMIN_SETUP_KEY not configured' }, { status: 500 });
  }
  if (setupKey !== expectedKey) {
    return NextResponse.json({ error: 'Invalid setup key' }, { status: 403 });
  }

  const count = await prisma.user.count();
  if (count > 0) {
    return NextResponse.json({ error: 'Setup already completed. Users exist.' }, { status: 400 });
  }

  if (!username || username.length < 3) {
    return NextResponse.json({ error: 'Username min 3 chars' }, { status: 400 });
  }
  if (!password || password.length < 8) {
    return NextResponse.json({ error: 'Password min 8 chars' }, { status: 400 });
  }

  const user = await prisma.user.create({
    data: {
      username: username.trim().toLowerCase(),
      passwordHash: hashPassword(password),
      displayName: username,
      role: 'owner',
    },
  });

  return NextResponse.json({
    ok: true,
    user: { username: user.username, role: user.role },
    message: 'Admin created. You can now login at /login',
  });
}

// GET: check if setup needed
export async function GET() {
  const count = await prisma.user.count();
  return NextResponse.json({
    setupNeeded: count === 0,
    hasUsers: count > 0,
    hasSetupKey: !!(process.env.ADMIN_SETUP_KEY || ''),
  });
}
EOF

# ---------- 9. Login page (username + password) ----------
echo "📝 app/login/page.tsx..."
mkdir -p app/login
cat > app/login/page.tsx <<'EOF'
'use client';
import { useState, Suspense, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [setupNeeded, setSetupNeeded] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    fetch('/api/auth/setup')
      .then(r => r.json())
      .then(j => setSetupNeeded(j.setupNeeded))
      .catch(() => {})
      .finally(() => setChecking(false));
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      const r = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Login failed');
      router.push(next);
      router.refresh();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center px-6 py-16">
      <div className="aurora" aria-hidden />

      <div className="relative z-10 w-full max-w-md">
        <Link href="/" className="inline-flex items-center gap-2 mb-8 text-sm text-slate-400 hover:text-white transition">
          ← Back to home
        </Link>

        <div className="card animate-in-slow !p-8">
          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-pink-500 mx-auto mb-4 floaty" />
            <h1 className="text-2xl font-semibold tracking-tight">
              {setupNeeded ? 'Initial Setup' : 'Team Login'}
            </h1>
            <p className="text-sm text-slate-400 mt-2">
              {setupNeeded
                ? 'Create the first admin account'
                : 'Sign in with your team credentials'}
            </p>
          </div>

          {checking ? (
            <div className="text-center text-slate-500 text-sm py-6">Loading…</div>
          ) : setupNeeded ? (
            <SetupForm onDone={() => setSetupNeeded(false)} />
          ) : (
            <form onSubmit={submit} className="space-y-4">
              <div>
                <label className="text-xs text-slate-400 mb-1.5 block">Username</label>
                <input
                  type="text"
                  required
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  placeholder="your-username"
                  className="input"
                  autoComplete="username"
                  autoFocus
                />
              </div>
              <div>
                <label className="text-xs text-slate-400 mb-1.5 block">Password</label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="input"
                  autoComplete="current-password"
                />
              </div>

              {err && (
                <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                  {err}
                </div>
              )}

              <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">
                {busy ? 'Signing in…' : 'Sign in →'}
              </button>
            </form>
          )}

          <div className="mt-6 text-xs text-slate-500 text-center leading-relaxed">
            🔒 Invite-only platform. Access is managed by the admin.
          </div>
        </div>
      </div>
    </div>
  );
}

function SetupForm({ onDone }: { onDone: () => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [setupKey, setSetupKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      const r = await fetch('/api/auth/setup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, setupKey }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || 'Setup failed');
      onDone();
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl px-4 py-3 text-xs text-blue-300">
        👋 First time setup. Create your admin account.
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Admin Username</label>
        <input type="text" required value={username} onChange={e => setUsername(e.target.value)} placeholder="admin" className="input" />
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Password (min 8 chars)</label>
        <input type="password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" className="input" />
      </div>
      <div>
        <label className="text-xs text-slate-400 mb-1.5 block">Setup Key (from Vercel env)</label>
        <input type="text" required value={setupKey} onChange={e => setSetupKey(e.target.value)} placeholder="ADMIN_SETUP_KEY value" className="input" />
        <p className="text-xs text-slate-500 mt-1">
          Vercel → Environment Variables → <code className="bg-white/5 px-1 rounded">ADMIN_SETUP_KEY</code>
        </p>
      </div>
      {err && <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">{err}</div>}
      <button type="submit" disabled={busy} className="btn btn-primary w-full py-3">
        {busy ? 'Creating…' : 'Create Admin →'}
      </button>
    </form>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}
EOF

# ---------- 10. Team management page ----------
echo "📝 app/team/page.tsx..."
mkdir -p app/team
cat > app/team/page.tsx <<'EOF'
'use client';
import { useEffect, useState } from 'react';

type Member = {
  id: string;
  username: string;
  displayName: string | null;
  role: string;
  isActive: boolean;
  lastLoginAt: string | null;
  createdAt: string;
};

export default function TeamPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [me, setMe] = useState<any>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  // New member form
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newDisplay, setNewDisplay] = useState('');
  const [newRole, setNewRole] = useState('member');
  const [showForm, setShowForm] = useState(false);

  const load = async () => {
    const [tRes, mRes] = await Promise.all([
      fetch('/api/team'),
      fetch('/api/auth/me'),
    ]);
    const t = await tRes.json();
    const m = mRes.ok ? await mRes.json() : null;
    setMembers(t.members ?? []);
    setMe(m?.user ?? null);
  };

  useEffect(() => { load(); }, []);

  const addMember = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setMsg('');
    const r = await fetch('/api/team', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: newUsername, password: newPassword, displayName: newDisplay, role: newRole }),
    });
    const j = await r.json();
    if (r.ok) {
      setMsg(`✅ Member added. Password: ${j.password} (save this now!)`);
      setNewUsername(''); setNewPassword(''); setNewDisplay(''); setNewRole('member');
      setShowForm(false);
      load();
    } else {
      setMsg('❌ ' + (j.error || 'Failed'));
    }
    setBusy(false);
  };

  const resetPassword = async (id: string, username: string) => {
    if (!confirm(`Reset password for ${username}?`)) return;
    const r = await fetch('/api/team', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, action: 'reset-password' }),
    });
    const j = await r.json();
    if (r.ok) {
      alert(`New password for ${username}:\n\n${j.password}\n\nCopy this now!`);
    } else {
      alert('Failed: ' + (j.error || 'unknown'));
    }
  };

  const toggleActive = async (id: string, current: boolean) => {
    await fetch('/api/team', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, isActive: !current }),
    });
    load();
  };

  const changeRole = async (id: string, role: string) => {
    await fetch('/api/team', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, role }),
    });
    load();
  };

  const removeMember = async (id: string, username: string) => {
    if (!confirm(`Delete ${username} permanently?`)) return;
    const r = await fetch('/api/team', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    const j = await r.json();
    if (r.ok) load();
    else alert('Failed: ' + (j.error || 'unknown'));
  };

  const isOwner = me?.role === 'owner';

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">👥 Team Management</h1>
          <p className="text-sm text-slate-400 mt-1">Invite-only access. Only owners can manage members.</p>
        </div>
        {isOwner && (
          <button className="btn btn-primary" onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Add Member'}
          </button>
        )}
      </div>

      {msg && (
        <div className="card text-sm break-all">
          {msg}
        </div>
      )}

      {!isOwner && (
        <div className="card text-sm text-amber-300 bg-amber-500/10 border-amber-500/20">
          ⚠️ Only the owner can manage team members. You're signed in as <b>{me?.username}</b> ({me?.role}).
        </div>
      )}

      {showForm && isOwner && (
        <form onSubmit={addMember} className="card animate-in space-y-4">
          <h2 className="font-semibold">➕ Add New Team Member</h2>
          <div className="grid md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Username *</label>
              <input className="input" required value={newUsername} onChange={e => setNewUsername(e.target.value)} placeholder="sales-person" />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Display Name</label>
              <input className="input" value={newDisplay} onChange={e => setNewDisplay(e.target.value)} placeholder="Sales Person" />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Password</label>
              <input className="input" type="text" value={newPassword} onChange={e => setNewPassword(e.target.value)} placeholder="Leave empty for auto-generate" />
            </div>
            <div>
              <label className="text-xs text-slate-400 mb-1.5 block">Role</label>
              <select className="input" value={newRole} onChange={e => setNewRole(e.target.value)}>
                <option value="member">Member</option>
                <option value="owner">Owner</option>
              </select>
            </div>
          </div>
          <button type="submit" className="btn btn-primary" disabled={busy}>
            {busy ? 'Creating…' : 'Create Member'}
          </button>
        </form>
      )}

      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-white/5 text-slate-400 text-left text-xs uppercase">
            <tr>
              <th className="p-3">Member</th>
              <th className="p-3">Role</th>
              <th className="p-3">Status</th>
              <th className="p-3">Last Login</th>
              <th className="p-3">Created</th>
              {isOwner && <th className="p-3 text-right">Actions</th>}
            </tr>
          </thead>
          <tbody>
            {members.map(m => (
              <tr key={m.id} className="border-t border-white/5">
                <td className="p-3">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center text-xs font-bold">
                      {m.username[0].toUpperCase()}
                    </div>
                    <div>
                      <div className="font-medium">{m.displayName || m.username}</div>
                      <div className="text-xs text-slate-500">@{m.username}</div>
                    </div>
                  </div>
                </td>
                <td className="p-3">
                  {isOwner ? (
                    <select className="bg-white/5 border border-white/10 rounded px-2 py-1 text-xs" value={m.role} onChange={e => changeRole(m.id, e.target.value)}>
                      <option value="member">Member</option>
                      <option value="owner">Owner</option>
                    </select>
                  ) : (
                    <span className={m.role === 'owner' ? 'text-amber-400' : 'text-slate-300'}>{m.role}</span>
                  )}
                </td>
                <td className="p-3">
                  <span className={m.isActive ? 'text-green-400' : 'text-red-400'}>
                    {m.isActive ? '● Active' : '● Disabled'}
                  </span>
                </td>
                <td className="p-3 text-xs text-slate-500">
                  {m.lastLoginAt ? new Date(m.lastLoginAt).toLocaleString() : 'Never'}
                </td>
                <td className="p-3 text-xs text-slate-500">
                  {new Date(m.createdAt).toLocaleDateString()}
                </td>
                {isOwner && (
                  <td className="p-3 text-right">
                    <div className="flex gap-1 justify-end flex-wrap">
                      <button onClick={() => resetPassword(m.id, m.username)} className="text-xs px-2 py-1 rounded bg-white/5 hover:bg-white/10">Reset pwd</button>
                      <button onClick={() => toggleActive(m.id, m.isActive)} className="text-xs px-2 py-1 rounded bg-white/5 hover:bg-white/10">
                        {m.isActive ? 'Disable' : 'Enable'}
                      </button>
                      {m.username !== me?.username && (
                        <button onClick={() => removeMember(m.id, m.username)} className="text-xs px-2 py-1 rounded bg-red-500/20 hover:bg-red-500/30 text-red-300">Delete</button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            ))}
            {members.length === 0 && (
              <tr>
                <td colSpan={isOwner ? 6 : 5} className="p-8 text-center text-slate-500">
                  No members yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="card text-xs text-slate-500 space-y-2">
        <div><b className="text-slate-300">🔐 Security</b></div>
        <ul className="list-disc list-inside space-y-1">
          <li>Passwords hashed with scrypt (Node built-in, no plaintext storage)</li>
          <li>Sessions signed with HMAC-SHA256, 30-day expiry</li>
          <li>Only owners can manage team members</li>
          <li>You cannot delete yourself (safety)</li>
        </ul>
      </div>
    </div>
  );
}
EOF

# ---------- 11. Middleware ----------
echo "📝 middleware.ts..."
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

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/team/:path*',
  ],
};
EOF
sed -i 's/\r$//' middleware.ts

# ---------- 12. Update dashboard layout ----------
echo "📝 app/dashboard/layout.tsx..."
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
        <div className="max-w-7xl mx-auto px-6 py-3 flex items-center justify-between">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-violet-500 to-pink-500" />
            <span className="font-semibold tracking-tight text-sm">EmailCampaign</span>
          </Link>
          <div className="flex items-center gap-1 flex-wrap">
            <Link href="/dashboard" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Campaign</Link>
            <Link href="/senders" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Senders</Link>
            <Link href="/senders/rotation" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Rotation</Link>
            <Link href="/anti-spam" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">🛡️ Anti-Spam</Link>
            <Link href="/team" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">👥 Team</Link>
            <Link href="/history" className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">History</Link>
            <div className="w-px h-5 bg-white/10 mx-2" />
            <span className="text-xs text-slate-500 hidden md:inline">
              @{session.username} {session.role === 'owner' && <span className="text-amber-400">●</span>}
            </span>
            <LogoutButton />
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
    </div>
  );
}
EOF

# ---------- 13. Update landing page ----------
echo "📝 app/page.tsx (updated CTA)..."
node <<'NODEEOF'
const fs = require('fs');
if (!fs.existsSync('app/page.tsx')) process.exit(0);
let s = fs.readFileSync('app/page.tsx', 'utf8');
// Replace all /login hrefs — those stay; just ensure no /register link
s = s.replace(/href="\/register"/g, 'href="/login"');
fs.writeFileSync('app/page.tsx', s);
console.log('   ✅ Landing updated');
NODEEOF

# ---------- 14. env example ----------
echo ""
echo "📝 Updating .env.example..."
cat > .env.example <<'EOF'
# Database
DATABASE_URL="postgresql://user:pass@host/db?sslmode=require"

# Redis
REDIS_URL="rediss://default:pass@host:6379"

# Google OAuth
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_REDIRECT_URI="https://emailcampaign-ten.vercel.app/api/oauth/google/callback"

# Security
TOKEN_ENCRYPTION_KEY="<64 hex chars — openssl rand -hex 32>"
SESSION_SECRET="<96 hex chars — openssl rand -hex 48>"

# Admin setup (used ONCE to create first admin)
ADMIN_SETUP_KEY="<random secret — openssl rand -hex 16>"

# App
APP_URL="https://emailcampaign-ten.vercel.app"
NODE_ENV="production"
EOF

# ---------- 15. Git push ----------
echo ""
echo "🌿 Git..."
if [ ! -d ".git" ]; then git init; git branch -M main; fi
REPO_URL="https://github.com/dipenzala/emailcampaign.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REPO_URL" || git remote add origin "$REPO_URL"
git config user.email "63999328+dipenzala@users.noreply.github.com"
git config user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: username+password auth (invite-only team)"
git push -u origin main

echo ""
echo "==================================================="
echo " ✅ PUSHED — Username/Password Auth"
echo "==================================================="
echo ""
echo "🚨 VERCEL ME 1 NAYA ENV VAR ADD KARO:"
echo ""
echo "   https://vercel.com/certwinx/emailcampaign/settings/environment-variables"
echo ""
echo "   ┌───────────────────────────────────────────────────┐"
echo "   │ Key:   ADMIN_SETUP_KEY                            │"
echo "   │ Value: $(openssl rand -hex 16 2>/dev/null || node -e "console.log(require('crypto').randomBytes(16).toString('hex'))")"
echo "   └───────────────────────────────────────────────────┘"
echo ""
echo "   👆 Ye value SAVE karo (setup me daalni hai)"
echo "   Phir Redeploy"
echo ""
echo "📋 SETUP FLOW:"
echo ""
echo "   STEP 1: Vercel me ADMIN_SETUP_KEY add karo + Redeploy"
echo ""
echo "   STEP 2: /login kholo — 'Initial Setup' form dikhega"
echo "           Username: admin  (jo bhi chaho)"
echo "           Password: (strong password)"
echo "           Setup Key: (Vercel me jo daala wahi)"
echo "           → Create Admin"
echo ""
echo "   STEP 3: Ab /login pe normal form aayega"
echo "           Username + Password se login karo"
echo ""
echo "   STEP 4: /team pe jao — apne team members add karo"
echo "           Username, display name, role"
echo "           Auto-generated password milega — copy karke unhe do"
echo ""
echo "🎯 ADVANTAGES:"
echo "   ✅ No email needed — pure username/password"
echo "   ✅ Invite-only (koi register nahi kar sakta)"
echo "   ✅ Admin controls everything"
echo "   ✅ Password reset by admin (not user)"
echo "   ✅ Enable/disable members instantly"
echo "   ✅ Role-based (owner vs member)"
echo "   ✅ Scrypt hashing (secure, no plaintext)"
echo ""
echo "🔐 SECURITY FLOW:"
echo "   → Only owner can add/remove members"
echo "   → Sessions signed, 30-day expiry"
echo "   → Disabled members can't login"
echo "   → Self-delete blocked"
echo ""
echo "📸 SCREENSHOTS BHEJO after deploy:"
echo "   1. /login (setup form)"
echo "   2. /login (normal login form)"
echo "   3. /dashboard (workflow)"
echo "   4. /team (member list)"
echo "==================================================="