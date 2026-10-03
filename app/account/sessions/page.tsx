'use client';
import { useEffect, useState } from 'react';

type S = {
  id: string;
  deviceId: string;
  deviceName: string;
  ip: string | null;
  createdAt: string;
  lastSeenAt: string;
  expiresAt: string;
  isCurrent: boolean;
};

export default function SessionsPage() {
  const [sessions, setSessions] = useState<S[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  const load = async () => {
    const r = await fetch('/api/account/sessions');
    if (r.ok) {
      const j = await r.json();
      setSessions(j.sessions ?? []);
    }
  };

  useEffect(() => { load(); }, []);

  const revokeOne = async (id: string) => {
    if (!confirm('Revoke this session?')) return;
    setBusy(true);
    await fetch('/api/account/sessions', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await load();
    setBusy(false);
    setMsg('✅ Session revoked');
    setTimeout(() => setMsg(''), 2500);
  };

  const revokeOthers = async () => {
    if (!confirm('Sign out ALL other devices?')) return;
    setBusy(true);
    await fetch('/api/account/sessions', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ all: true, exceptCurrent: true }),
    });
    await load();
    setBusy(false);
    setMsg('✅ Other devices signed out');
    setTimeout(() => setMsg(''), 2500);
  };

  const revokeAll = async () => {
    if (!confirm('Sign out from ALL devices including this one?')) return;
    setBusy(true);
    await fetch('/api/account/sessions', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ all: true }),
    });
    window.location.href = '/login';
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight text-[#1d1d1f]">🔐 Active Sessions</h1>
          <p className="text-sm text-[#86868b] mt-1">Devices currently signed in with your account.</p>
        </div>
        <div className="flex gap-2">
          <button onClick={revokeOthers} disabled={busy} className="btn btn-ghost text-sm">
            Sign out others
          </button>
          <button onClick={revokeAll} disabled={busy} className="btn btn-danger text-sm">
            Sign out all
          </button>
        </div>
      </div>

      {msg && <div className="card text-sm text-[#30d158] fade-up">{msg}</div>}

      <div className="card !p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-black/[0.03] text-[#86868b] text-left text-xs uppercase">
            <tr>
              <th className="p-3">Device</th>
              <th className="p-3">IP</th>
              <th className="p-3">Signed in</th>
              <th className="p-3">Last active</th>
              <th className="p-3">Expires</th>
              <th className="p-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {sessions.map(s => (
              <tr key={s.id} className="border-t border-black/[0.05]">
                <td className="p-3">
                  <div className="flex items-center gap-2">
                    <span className="text-base">{s.isCurrent ? '📍' : '💻'}</span>
                    <div>
                      <div className="font-medium text-[#1d1d1f]">
                        {s.deviceName}
                        {s.isCurrent && <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#30d158]/15 text-[#30d158]">THIS DEVICE</span>}
                      </div>
                      <div className="text-xs text-[#86868b]">ID: {s.deviceId.slice(0, 12)}…</div>
                    </div>
                  </div>
                </td>
                <td className="p-3 text-xs text-[#6e6e73]">{s.ip || '—'}</td>
                <td className="p-3 text-xs text-[#6e6e73]">{new Date(s.createdAt).toLocaleString()}</td>
                <td className="p-3 text-xs text-[#6e6e73]">{new Date(s.lastSeenAt).toLocaleString()}</td>
                <td className="p-3 text-xs text-[#6e6e73]">{new Date(s.expiresAt).toLocaleDateString()}</td>
                <td className="p-3 text-right">
                  {!s.isCurrent && (
                    <button onClick={() => revokeOne(s.id)} disabled={busy} className="text-xs px-2.5 py-1 rounded-md bg-[#ff3b30]/10 text-[#ff3b30] hover:bg-[#ff3b30]/20 transition">
                      Revoke
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {sessions.length === 0 && (
              <tr><td colSpan={6} className="p-8 text-center text-[#86868b]">No active sessions.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="card text-xs text-[#6e6e73] space-y-2">
        <div className="font-semibold text-[#1d1d1f] text-sm">🔒 How sessions work</div>
        <ul className="list-disc list-inside space-y-1">
          <li>Each login binds to a unique device fingerprint</li>
          <li>Session tokens are HMAC-signed and validated on every request</li>
          <li>Tokens are hashed in DB — cannot be stolen from backup</li>
          <li>Revoke any session instantly</li>
          <li>Sessions auto-expire after 30 days</li>
        </ul>
      </div>
    </div>
  );
}
