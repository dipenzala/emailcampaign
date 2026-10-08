/**
 * Trigger GitHub Actions workflow from Vercel/backend.
 *
 * Env vars required:
 *   GITHUB_PAT   — Personal Access Token (scopes: repo, workflow)
 *   GITHUB_REPO  — "owner/repo" format (e.g. "dipenzala/emailcampaign")
 */

const GITHUB_API = 'https://api.github.com';

export async function triggerBotWorkflow(opts: {
  batchSize?: number;
  mode?: 'run' | 'once';
} = {}): Promise<{ ok: boolean; status?: number; error?: string }> {
  const pat = process.env.GITHUB_PAT;
  const repo = process.env.GITHUB_REPO || 'dipenzala/emailcampaign';

  if (!pat) {
    console.warn('[gh-trigger] GITHUB_PAT not set — skipping trigger');
    return { ok: false, error: 'GITHUB_PAT not configured' };
  }

  const url = `${GITHUB_API}/repos/${repo}/actions/workflows/bots.yml/dispatches`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ref: 'main',
        inputs: {
          batch_size: String(opts.batchSize || 20),
          mode: opts.mode || 'run',
        },
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.warn('[gh-trigger] API failed:', res.status, text.slice(0, 200));
      return { ok: false, status: res.status, error: text.slice(0, 200) };
    }

    console.log('[gh-trigger] ✅ Workflow triggered');
    return { ok: true, status: res.status };
  } catch (err: any) {
    console.error('[gh-trigger] fetch error:', err.message);
    return { ok: false, error: err.message };
  }
}
