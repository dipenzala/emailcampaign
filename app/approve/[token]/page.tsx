'use client';
import { useEffect, useState } from 'react';
import { useParams, useSearchParams } from 'next/navigation';
import Link from 'next/link';

export default function ApprovePage() {
  const params = useParams<{ token: string }>();
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('');
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    const action = searchParams.get('action') || 'approve';
    fetch(`/api/approve/${params.token}?action=${action}`)
      .then(r => r.json())
      .then(j => {
        if (j.ok) {
          setStatus('success');
          setMessage(j.message);
          setData(j);
        } else {
          setStatus('error');
          setMessage(j.error);
        }
      })
      .catch(e => {
        setStatus('error');
        setMessage(e.message);
      });
  }, [params.token, searchParams]);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
      <div className="card" style={{ maxWidth: 520, width: '100%', padding: 40, textAlign: 'center' }}>
        {status === 'loading' && (
          <>
            <div style={{ fontSize: 60, marginBottom: 16 }}>⏳</div>
            <h1 style={{ fontSize: 22 }}>Processing...</h1>
          </>
        )}

        {status === 'success' && data?.status === 'APPROVED' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>✅</div>
            <h1 style={{ fontSize: 26, fontWeight: 800, color: '#065f46', marginBottom: 12 }}>
              Approved!
            </h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14, marginBottom: 20 }}>
              Campaign is now LIVE. Emails starting to {data.totalRecipients?.toLocaleString() || '0'} recipients.
            </p>
            <Link href="/dashboard/live" className="btn btn-primary" style={{ display: 'inline-flex' }}>
              📊 View Live Dashboard
            </Link>
          </>
        )}

        {status === 'success' && data?.status === 'REJECTED' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>🛑</div>
            <h1 style={{ fontSize: 26, fontWeight: 800, color: '#991b1b', marginBottom: 12 }}>
              Campaign Cancelled
            </h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>
              No emails will be sent. Campaign is stopped.
            </p>
          </>
        )}

        {status === 'error' && (
          <>
            <div style={{ fontSize: 72, marginBottom: 16 }}>❌</div>
            <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 12 }}>Error</h1>
            <p style={{ color: 'var(--fg-muted)', fontSize: 14 }}>{message}</p>
          </>
        )}
      </div>
    </div>
  );
}
