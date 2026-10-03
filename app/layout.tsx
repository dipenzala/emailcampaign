import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'EmailCampaign', description: 'Modern email campaign platform.' };
export default function Root({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="min-h-screen antialiased">{children}</body></html>;
}
