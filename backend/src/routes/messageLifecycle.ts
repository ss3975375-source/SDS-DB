import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { listReceipts, markDelivered, markRead } from '../services/messageLifecycleService.js';

const params = z.object({ messageId: z.string().uuid() });
export const messageLifecycleRoutes: FastifyPluginAsync = async (app) => {
  app.post('/:messageId/delivered', { preHandler: requireAuth }, async (req, reply) => {
    const p = params.safeParse(req.params); if (!p.success) return reply.code(400).send({ error: 'invalid_message_id' });
    try { await markDelivered(req.auth.userId, p.data.messageId); return reply.code(204).send(); }
    catch (e) { if (e instanceof Error && e.message === 'FORBIDDEN') return reply.code(403).send({ error: 'forbidden' }); throw e; }
  });
  app.post('/:messageId/read', { preHandler: requireAuth }, async (req, reply) => {
    const p = params.safeParse(req.params); if (!p.success) return reply.code(400).send({ error: 'invalid_message_id' });
    try { await markRead(req.auth.userId, p.data.messageId); return reply.code(204).send(); }
    catch (e) { if (e instanceof Error && e.message === 'FORBIDDEN') return reply.code(403).send({ error: 'forbidden' }); throw e; }
  });
  app.get('/:messageId/receipts', { preHandler: requireAuth }, async (req, reply) => {
    const p = params.safeParse(req.params); if (!p.success) return reply.code(400).send({ error: 'invalid_message_id' });
    try { return reply.send({ items: await listReceipts(req.auth.userId, p.data.messageId) }); }
    catch (e) { if (e instanceof Error && e.message === 'FORBIDDEN') return reply.code(403).send({ error: 'forbidden' }); throw e; }
  });
};
