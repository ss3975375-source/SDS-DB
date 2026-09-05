import { jwtVerify } from 'jose';
import type { FastifyRequest } from 'fastify';
import { config } from '../config/env.js';
import { pool } from '../db/pool.js';

const key = new TextEncoder().encode(config.jwtSecret);

export type AuthContext = { userId: string; sessionId: string };

declare module 'fastify' {
  interface FastifyRequest { auth: AuthContext; }
}

export async function requireAuth(request: FastifyRequest): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHENTICATED');
  const token = header.slice('Bearer '.length);
  const { payload } = await jwtVerify(token, key, { algorithms: ['HS256'] });
  if (payload.typ !== 'access' || typeof payload.sub !== 'string' || typeof payload.sid !== 'string') {
    throw new Error('UNAUTHENTICATED');
  }
  const session = await pool.query(
    `SELECT s.user_id, s.device_id FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.id = $1 AND s.revoked_at IS NULL AND s.expires_at > now() AND u.deleted_at IS NULL`,
    [payload.sid],
  );
  if (session.rows.length === 0 || session.rows[0].user_id !== payload.sub) throw new Error('UNAUTHENTICATED');
  await pool.query('UPDATE sessions SET last_seen_at = now() WHERE id = $1 AND revoked_at IS NULL', [payload.sid]);
  if (session.rows[0].device_id) await pool.query('UPDATE devices SET last_seen_at = now() WHERE id = $1 AND revoked_at IS NULL', [session.rows[0].device_id]);
  request.auth = { userId: payload.sub, sessionId: payload.sid };
}
