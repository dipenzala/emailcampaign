import './globals.css';
import type { Metadata } from 'next';
import AppShell from '@/components/AppShell';
import ToastContainer from '@/components/Toast';

export const metadata: Metadata = {
  title: 'EmailCampaign — Premium',
  description: 'Premium email campaign platform.',
};

export default function Root({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased" suppressHydrationWarning>
        <AppShell>{children}</AppShell>
        <ToastContainer />
      </body>
    </html>
  );
}
