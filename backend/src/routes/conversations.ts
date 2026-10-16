import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const directSchema = z.object({ userId: z.string().uuid() });

export const conversationRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', { preHandler: requireAuth }, async (request, reply) => {
    const result = await pool.query(
      `SELECT c.id AS "conversationId", c.kind,
              CASE WHEN c.kind='group' THEN g.name ELSE other.display_name END AS name,
              CASE WHEN c.kind='group' THEN (
                SELECT count(*)::int FROM conversation_members cm2
                 WHERE cm2.conversation_id=c.id AND cm2.left_at IS NULL
              ) ELSE 2 END AS "memberCount",
              latest.body AS "lastMessage",
              latest.created_at AS "lastMessageAt"
         FROM conversation_members mine
         JOIN conversations c ON c.id=mine.conversation_id AND c.deleted_at IS NULL
         LEFT JOIN groups g ON g.conversation_id=c.id
         LEFT JOIN LATERAL (
           SELECT u.display_name
             FROM conversation_members peer
             JOIN users u ON u.id=peer.user_id
            WHERE peer.conversation_id=c.id AND peer.user_id<>$1 AND peer.left_at IS NULL
            ORDER BY peer.joined_at LIMIT 1
         ) other ON c.kind='direct'
         LEFT JOIN LATERAL (
           SELECT m.body,m.created_at FROM messages m
            WHERE m.conversation_id=c.id AND m.deleted_at IS NULL
              AND (m.expires_at IS NULL OR m.expires_at>now())
            ORDER BY m.created_at DESC,m.id DESC LIMIT 1
         ) latest ON true
        WHERE mine.user_id=$1 AND mine.left_at IS NULL
        ORDER BY latest.created_at DESC NULLS LAST, c.created_at DESC
        LIMIT 200`,
      [request.auth.userId],
    );
    return reply.send({ conversations: result.rows });
  });

  app.post('/direct', { preHandler: requireAuth }, async (request, reply) => {
    const parsed = directSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_contact_id' });
    const userId = request.auth.userId;
    const otherId = parsed.data.userId;
    if (userId === otherId) return reply.code(400).send({ error: 'cannot_message_self' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const lockKey = [userId, otherId].sort().join(':');
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [lockKey]);
      const blocked = await client.query(
        'SELECT 1 FROM blocks WHERE (user_id=$1 AND blocked_user_id=$2) OR (user_id=$2 AND blocked_user_id=$1) LIMIT 1',
        [userId, otherId],
      );
      if (blocked.rows[0]) {
        await client.query('ROLLBACK');
        return reply.code(403).send({ error: 'contact_unavailable' });
      }
      const contacts = await client.query(
        `SELECT count(*)::int AS count FROM contacts
          WHERE status='accepted' AND ((user_id=$1 AND contact_user_id=$2) OR (user_id=$2 AND contact_user_id=$1))`,
        [userId, otherId],
      );
      if (contacts.rows[0]?.count !== 2) {
        await client.query('ROLLBACK');
        return reply.code(403).send({ error: 'accepted_contact_required' });
      }
      const activeUsers = await client.query(
        'SELECT id FROM users WHERE id = ANY($1::uuid[]) AND deleted_at IS NULL',
        [[userId, otherId]],
      );
      if (activeUsers.rowCount !== 2) {
        await client.query('ROLLBACK');
        return reply.code(404).send({ error: 'user_not_found' });
      }
      const existing = await client.query(
        `SELECT c.id FROM conversations c
          JOIN conversation_members a ON a.conversation_id=c.id AND a.user_id=$1 AND a.left_at IS NULL
          JOIN conversation_members b ON b.conversation_id=c.id AND b.user_id=$2 AND b.left_at IS NULL
         WHERE c.kind='direct' AND c.deleted_at IS NULL
           AND (SELECT count(*) FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.left_at IS NULL)=2
         LIMIT 1`,
        [userId, otherId],
      );
      if (existing.rows[0]) {
        await client.query('COMMIT');
        return reply.send({ conversationId: existing.rows[0].id, created: false });
      }
      const created = await client.query(`INSERT INTO conversations(kind) VALUES('direct') RETURNING id`);
      const conversationId = created.rows[0].id as string;
      await client.query(
        `INSERT INTO conversation_members(conversation_id,user_id,role) VALUES($1,$2,'member'),($1,$3,'member')`,
        [conversationId, userId, otherId],
      );
      await client.query('COMMIT');
      return reply.code(201).send({ conversationId, created: true });
    } catch (error) {
      await client.query('ROLLBACK');
      request.log.error({ err: error }, 'direct conversation creation failed');
      return reply.code(500).send({ error: 'unable_to_open_conversation' });
    } finally {
      client.release();
    }
  });
};
