import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { DIRECT_DAILY_LIMIT, GROUP_DAILY_LIMIT, reserveUploadQuota } from '../services/quota.service.js';
import { pool } from '../db/pool.js';

const reserveSchema = z.object({ conversationId: z.string().uuid(), bytes: z.coerce.bigint().positive() });

export const quotaRoutes: FastifyPluginAsync = async (app) => {
  app.post('/quota/reserve', { preHandler: requireAuth }, async (request, reply) => {
    const parsed = reserveSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid quota request' });
    try {
      const remaining = await reserveUploadQuota(request.auth.userId, parsed.data.conversationId, parsed.data.bytes);
      return reply.send({ remainingBytes: remaining.toString() });
    } catch (error) {
      if (error instanceof Error && error.message === 'QUOTA_EXCEEDED') return reply.code(429).send({ error: 'Daily upload quota exceeded' });
      if (error instanceof Error && error.message === 'FORBIDDEN') return reply.code(403).send({ error: 'Not a conversation member' });
      return reply.code(400).send({ error: 'Unable to reserve upload quota' });
    }
  });

  app.get('/quota', { preHandler: requireAuth }, async (request, reply) => {
    const query = z.object({ conversationId: z.string().uuid() }).safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'Invalid conversationId' });
    const result = await pool.query(
      `SELECT c.kind, COALESCE(f.bytes_used, 0) AS bytes_used
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = $1 AND cm.left_at IS NULL
       LEFT JOIN file_usage_daily f ON f.conversation_id = c.id AND f.user_id = $1 AND f.usage_date = CURRENT_DATE
       WHERE c.id = $2 AND c.deleted_at IS NULL`, [request.auth.userId, query.data.conversationId]);
    if (!result.rows[0]) return reply.code(403).send({ error: 'Not a conversation member' });
    const limit = result.rows[0].kind === 'group' ? GROUP_DAILY_LIMIT : DIRECT_DAILY_LIMIT;
    return reply.send({
      scope: result.rows[0].kind,
      usedBytes: String(result.rows[0].bytes_used),
      limitBytes: limit.toString(),
      remainingBytes: (limit - BigInt(result.rows[0].bytes_used)).toString(),
    });
  });
};
