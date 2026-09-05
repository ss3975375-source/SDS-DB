import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { verifyGoogleIdentityToken } from '../services/google-token.service.js';
import { createSession, revokeSession, rotateSession } from '../services/session.service.js';
import { requireAuth } from '../middleware/auth.js';

const googleSchema = z.object({
  identityToken: z.string().min(20).max(10000),
  platform: z.enum(['android', 'ios', 'web', 'desktop']).default('android'),
  deviceLabel: z.string().trim().max(120).optional(),
  appVersion: z.string().trim().max(120).optional(),
});
const refreshSchema = z.object({ refreshToken: z.string().min(20).max(500) });

export const authRoutes: FastifyPluginAsync = async (app) => {
  app.post('/google', async (request, reply) => {
    const parsed = googleSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid authentication request' });

    try {
      const identity = await verifyGoogleIdentityToken(parsed.data.identityToken);
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const userResult = await client.query(
          `INSERT INTO users (google_subject, email, display_name, photo_url)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (google_subject) DO UPDATE SET
             email = EXCLUDED.email,
             display_name = EXCLUDED.display_name,
             photo_url = EXCLUDED.photo_url,
             updated_at = now(), deleted_at = NULL
           RETURNING id, email, display_name, photo_url`,
          [identity.subject, identity.email.toLowerCase(), identity.displayName, identity.photoUrl],
        );
        const user = userResult.rows[0];
        const deviceResult = await client.query(
          `INSERT INTO devices (user_id, platform, label, app_version, last_seen_at)
           VALUES ($1, $2, $3, $4, now()) RETURNING id`,
          [user.id, parsed.data.platform, parsed.data.deviceLabel ?? null, parsed.data.appVersion ?? null],
        );
        await client.query('COMMIT');
        const session = await createSession(user.id, deviceResult.rows[0].id);
        return reply.send({ user, ...session });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally { client.release(); }
    } catch {
      return reply.code(401).send({ error: 'Google authentication failed' });
    }
  });

  app.post('/refresh', async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid refresh request' });
    try { return reply.send(await rotateSession(parsed.data.refreshToken)); }
    catch { return reply.code(401).send({ error: 'Invalid or expired session' }); }
  });

  app.post('/logout', { preHandler: requireAuth }, async (request, reply) => {
    await revokeSession(request.auth.sessionId, request.auth.userId);
    return reply.code(204).send();
  });
};
