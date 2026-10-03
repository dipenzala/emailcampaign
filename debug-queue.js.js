const IORedis = require('ioredis');
const { Queue } = require('bullmq');

async function main() {
  const url = process.env.REDIS_URL;
  if (!url) { console.error('❌ REDIS_URL not set'); process.exit(1); }
  console.log('🔗 URL:', url.slice(0, 50) + '...');

  const redis = new IORedis(url, { maxRetriesPerRequest: null });

  await new Promise((resolve, reject) => {
    redis.once('ready', resolve);
    redis.once('error', reject);
    setTimeout(() => reject(new Error('Redis timeout')), 10000);
  });
  console.log('✅ Redis connected\n');

  // List keys matching emailcampaign
  const keys = await redis.keys('*');
  const ecKeys = keys.filter(k => k.toLowerCase().includes('emailcampaign'));
  console.log('=== emailcampaign* keys ===');
  console.log('Total:', ecKeys.length);
  ecKeys.slice(0, 30).forEach(k => console.log('  ', k));
  console.log('');

  // Queue counts
  const q = new Queue('email-send', { connection: redis, prefix: 'emailcampaign' });
  console.log('=== Queue: email-send (prefix=emailcampaign) ===');
  console.log('  waiting:  ', await q.getWaitingCount());
  console.log('  active:   ', await q.getActiveCount());
  console.log('  completed:', await q.getCompletedCount());
  console.log('  failed:   ', await q.getFailedCount());
  console.log('  delayed:  ', await q.getDelayedCount());
  console.log('');

  // Sample jobs
  const jobs = await q.getJobs(['waiting', 'active', 'failed', 'completed'], 0, 10);
  console.log('=== Sample jobs ===');
  if (jobs.length === 0) {
    console.log('  (no jobs found — ye problem hai)');
  } else {
    jobs.forEach(j => console.log('  ', j.id, '|', j.name, '| state:', j.getState ? 'unknown' : 'n/a'));
  }

  await q.close();
  await redis.quit();
  console.log('\n✅ Done');
}

main().catch(e => { console.error('❌ Error:', e.message); process.exit(1); });