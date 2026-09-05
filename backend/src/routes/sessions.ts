import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { pool } from '../db/pool.js';
import { revokeSession, revokeAllOtherSessions, revokeAllSessions } from '../services/session.service.js';
import { toSessionView } from '../services/sessionSecurityService.js';

const sessionParams = z.object({ sessionId: z.string().uuid() });

export async function registerSessionRoutes(app: FastifyInstance) {
  app.get('/api/v1/sessions', { preHandler: requireAuth }, async (request, reply) => {
    const result = await pool.query(
      `SELECT s.id, s.device_id, d.label AS device_name, d.platform, d.app_version,
              s.created_at, s.last_seen_at, s.revoked_at
         FROM sessions s
         LEFT JOIN devices d ON d.id = s.device_id
        WHERE s.user_id = $1
        ORDER BY s.revoked_at NULLS FIRST, s.last_seen_at DESC NULLS LAST, s.created_at DESC
        LIMIT 100`,
      [request.auth.userId],
    );
    return reply.send({
      items: result.rows.map((row) => toSessionView(row, request.auth.sessionId)),
    });
  });

  app.post('/api/v1/sessions/:sessionId/revoke', { preHandler: requireAuth }, async (request, reply) => {
    const parsed = sessionParams.safeParse(request.params);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_session_id' });
    const result = await revokeSession(parsed.data.sessionId, request.auth.userId);
    if (!result) return reply.code(404).send({ error: 'session_not_found' });
    return reply.code(204).send();
  });

  app.post('/api/v1/sessions/revoke-others', { preHandler: requireAuth }, async (request, reply) => {
    const count = await revokeAllOtherSessions(request.auth.userId, request.auth.sessionId);
    return reply.send({ revoked: count });
  });

  app.post('/api/v1/sessions/revoke-all', { preHandler: requireAuth }, async (request, reply) => {
    const count = await revokeAllSessions(request.auth.userId);
    return reply.send({ revoked: count });
  });
}
