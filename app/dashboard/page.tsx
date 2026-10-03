'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function DashboardRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace('/dashboard/live');
  }, [router]);
  return (
    <div className="flex items-center justify-center min-h-[60vh] text-slate-500 text-sm">
      Redirecting to Live Dashboard…
    </div>
  );
}
