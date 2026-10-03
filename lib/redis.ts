import IORedis from 'ioredis';

const g = globalThis as any;

function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();

  const commonOpts = {
    // Auto-connect on instantiation
    lazyConnect: false,

    // Queue commands while connecting — CRITICAL for BullMQ + Vercel
    enableOfflineQueue: true,

    // Connection reliability
    connectTimeout: 10000,
    maxRetriesPerRequest: null,   // BullMQ requirement

    // Reconnect strategy
    retryStrategy: (times: number) => {
      if (times > 10) {
        console.error('[redis] giving up after 10 retries');
        return null;
      }
      const delay = Math.min(times * 300, 3000);
      console.log('[redis] retry #' + times + ' in ' + delay + 'ms');
      return delay;
    },

    // Log connection events
    reconnectOnError: (err: Error) => {
      const target = ['READONLY', 'ETIMEDOUT'];
      return target.some(t => err.message.includes(t));
    },
  };

  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    console.warn('[redis] REDIS_URL missing or invalid — using localhost');
    return new IORedis({ host: '127.0.0.1', port: 6379, ...commonOpts });
  }

  const client = new IORedis(url, commonOpts);

  client.on('connect', () => console.log('[redis] connected'));
  client.on('ready', () => console.log('[redis] ready'));
  client.on('error', (e: Error) => console.error('[redis] error:', e.message));
  client.on('close', () => console.log('[redis] connection closed'));
  client.on('reconnecting', () => console.log('[redis] reconnecting...'));

  return client;
}

export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;

/**
 * Explicit connect + ping with timeout.
 * Use this in health checks / serverless routes.
 */
export async function connectRedis(timeoutMs = 8000): Promise<string> {
  const client = redis;
  if (client.status === 'ready') return 'PONG';

  // If not connected yet, wait for ready event
  if (client.status === 'connecting' || client.status === 'wait') {
    await new Promise<void>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('connect timeout')), timeoutMs);
      client.once('ready', () => { clearTimeout(t); resolve(); });
      client.once('error', (e: Error) => { clearTimeout(t); reject(e); });
    });
  }

  return client.ping();
}
