import IORedis from 'ioredis';

const g = globalThis as any;

function createRedis(): IORedis {
  const url = (process.env.REDIS_URL || '').trim();

  const commonOpts = {
    maxRetriesPerRequest: 2,
    connectTimeout: 5000,
    commandTimeout: 8000,
    enableOfflineQueue: false,
    enableReadyCheck: false,
    lazyConnect: true,
    retryStrategy: (times: number) => {
      if (times > 3) return null;
      return Math.min(times * 500, 2000);
    },
  };

  if (!url || !/^rediss?:\/\/[^\s]+$/.test(url)) {
    return new IORedis({ host: '127.0.0.1', port: 6379, ...commonOpts });
  }
  return new IORedis(url, commonOpts);
}

export const redis: IORedis = g.__redis ?? createRedis();
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
