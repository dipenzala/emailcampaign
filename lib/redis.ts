import IORedis from 'ioredis';
const g = globalThis as any;
export const redis = g.__redis ?? new IORedis(process.env.REDIS_URL!, { maxRetriesPerRequest: null });
if (process.env.NODE_ENV !== 'production') g.__redis = redis;
