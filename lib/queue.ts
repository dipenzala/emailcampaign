// ==========================================
// Queue stub — BullMQ removed
// Polling worker picks up QUEUED recipients directly from DB.
// ==========================================

export const SEND_QUEUE = 'email-send';
export const QUEUE_PREFIX = 'emailcampaign';

export function getSendQueue() {
  return {
    add: async () => ({ id: 'noop' }),
    addBulk: async () => [],
    close: async () => {},
  };
}

export const sendQueue = getSendQueue();
