import { Queue } from 'bullmq';
import { redis } from './redis';
export const SEND_QUEUE = 'email-send';
export const sendQueue = new Queue(SEND_QUEUE, { connection: redis });
