import './globals.css';
export const metadata = { title:'EmailCampaign' };
export default function Root({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <nav className="border-b border-slate-800 px-6 py-3 flex gap-4 items-center">
          <a href="/" className="font-bold text-lg">📧 EMAIL CAMPAIGN</a>
          <a href="/senders" className="text-sm text-slate-300 hover:text-white">Manage Senders</a>
          <a href="/history" className="text-sm text-slate-300 hover:text-white">History</a>
        </nav>
        <main className="p-6 max-w-6xl mx-auto">{children}</main>
      </body>
    </html>
  );
}
