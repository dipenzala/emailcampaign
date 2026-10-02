import { Queue } from 'bullmq';
import { redis } from './redis';
export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';
let _queue: Queue | null = null;
export function getSendQueue(): Queue {
  if (_queue) return _queue;
  _queue = new Queue(SEND_QUEUE, { connection: redis, prefix: QUEUE_PREFIX });
  return _queue;
}
export const sendQueue = new Proxy({} as Queue, {
  get(_t, prop) {
    const q = getSendQueue();
    const v = (q as any)[prop];
    return typeof v === 'function' ? v.bind(q) : v;
  },
});
