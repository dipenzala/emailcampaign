'use client';
import { useRouter } from 'next/navigation';
export default function LogoutButton() {
  const router = useRouter();
  return <button onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); router.push('/'); router.refresh(); }} className="text-sm text-slate-300 hover:text-white px-3 py-1.5 rounded-lg hover:bg-white/5 transition">Sign out</button>;
}
