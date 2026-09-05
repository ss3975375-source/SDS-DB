import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { decodeMessageCursor, syncMessages } from '../services/messageSyncService.js';

const conversationParams = z.object({ conversationId: z.string().uuid() });

const querySchema = z.object({
  cursor: z.string().min(1).max(512).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(100),
}).strict();

export const messageSyncRoutes: FastifyPluginAsync = async (app) => {
  app.get('/:conversationId/sync', { preHandler: requireAuth }, async (req, reply) => {
    const parsedParams = conversationParams.safeParse(req.params);
    const parsed = querySchema.safeParse(req.query);
    if (!parsedParams.success || !parsed.success) return reply.code(400).send({ error: 'Invalid sync cursor' });
    const cursor = decodeMessageCursor(parsed.data.cursor);
    if (parsed.data.cursor && !cursor) return reply.code(400).send({ error: 'Invalid sync cursor' });
    return reply.send(await syncMessages(req.auth.userId, cursor, parsed.data.limit, parsedParams.data.conversationId));
  });
};
