'use client';
import { useEffect, useState } from 'react';

export default function WorkerPage() {
  const [logs, setLogs] = useState<string[]>([]);
  const [running, setRunning] = useState(false);
  const [stats, setStats] = useState({ sent: 0, failed: 0, processed: 0 });
  const [tick, setTick] = useState(0);

  const runOnce = async () => {
    try {
      const r = await fetch('/api/worker/tick');
      const j = await r.json();
      setTick(t => t + 1);
      setStats(prev => ({
        sent: prev.sent + (j.sent ?? 0),
        failed: prev.failed + (j.failed ?? 0),
        processed: prev.processed + (j.processed ?? 0),
      }));
      const time = new Date().toLocaleTimeString();
      setLogs(prev => [
        `[${time}] processed=${j.processed ?? 0} sent=${j.sent ?? 0} failed=${j.failed ?? 0} suppressed=${j.suppressed ?? 0} bounced=${j.bounced ?? 0}`,
        ...prev.slice(0, 30),
      ]);
      if (j.message === 'No queued recipients' && running) {
        setLogs(prev => [`[${time}] ✅ All emails sent — stopping`, ...prev]);
        setRunning(false);
      }
    } catch (e: any) {
      setLogs(prev => [`[${new Date().toLocaleTimeString()}] ❌ ${e.message}`, ...prev]);
    }
  };

  useEffect(() => {
    if (!running) return;
    const iv = setInterval(runOnce, 5000);
    runOnce();
    return () => clearInterval(iv);
  }, [running]);

  return (
    <div className="min-h-screen bg-slate-950 text-white p-6">
      <div className="max-w-3xl mx-auto space-y-6">
        <h1 className="text-3xl font-bold">☁️ Vercel Worker</h1>
        <p className="text-slate-400">Har 5 second me 5 emails process honge.</p>

        <div className="grid grid-cols-3 gap-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-slate-500">TICKS</div>
            <div className="text-2xl font-bold">{tick}</div>
          </div>
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-emerald-400">SENT</div>
            <div className="text-2xl font-bold text-emerald-400">{stats.sent}</div>
          </div>
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="text-xs text-red-400">FAILED</div>
            <div className="text-2xl font-bold text-red-400">{stats.failed}</div>
          </div>
        </div>

        <div className="flex gap-3">
          <button
            onClick={() => setRunning(true)}
            disabled={running}
            className="px-6 py-3 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-xl font-medium"
          >
            {running ? '🟢 Running...' : '▶️ Start Worker'}
          </button>
          <button
            onClick={() => setRunning(false)}
            disabled={!running}
            className="px-6 py-3 bg-slate-700 hover:bg-slate-600 disabled:opacity-50 rounded-xl font-medium"
          >
            ⏸️ Pause
          </button>
          <button
            onClick={runOnce}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-500 rounded-xl font-medium"
          >
            ⏭️ Step Once
          </button>
        </div>

        <div className="bg-black border border-slate-800 rounded-xl p-4 h-96 overflow-auto font-mono text-xs">
          {logs.length === 0 ? (
            <div className="text-slate-500">Click "Start Worker" to begin...</div>
          ) : (
            logs.map((l, i) => (
              <div key={i} className="text-emerald-300 py-0.5">{l}</div>
            ))
          )}
        </div>

        <div className="text-xs text-slate-500">
          💡 Ye page open rakho — ye har 5 sec me Vercel pe tick endpoint call karega.
          Emails send hote rahenge. Band karo to ruk jayega.
        </div>
      </div>
    </div>
  );
}
