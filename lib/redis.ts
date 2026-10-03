import IORedis from 'ioredis';
const g = globalThis as any;
function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();
  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    return new IORedis({ host: '127.0.0.1', port: 6379, lazyConnect: true, maxRetriesPerRequest: null, enableOfflineQueue: false });
  }
  return new IORedis(url, { maxRetriesPerRequest: null, enableReadyCheck: false, lazyConnect: true });
}
export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
