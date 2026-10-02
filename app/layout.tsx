import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'EmailCampaign — Send beautifully',
  description: 'A modern email campaign platform. Gmail OAuth, real-time dashboard, zero spam.',
};

export default function Root({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
