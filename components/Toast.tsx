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
