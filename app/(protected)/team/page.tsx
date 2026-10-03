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
