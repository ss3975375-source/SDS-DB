import { SignJWT } from 'jose';
import { config } from '../config/env.js';
import { pool } from '../db/pool.js';
import { randomToken, sha256 } from '../utils/hash.js';

const jwtKey = new TextEncoder().encode(config.jwtSecret);

async function signAccessToken(sessionId: string, userId: string) {
  return new SignJWT({ sid: sessionId, sub: userId, typ: 'access' })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime(`${config.accessTokenTtlSeconds}s`)
    .sign(jwtKey);
}

export async function createSession(userId: string, deviceId: string | null) {
  const refreshToken = randomToken(48);
  const refreshHash = sha256(refreshToken);
  const expiresAt = new Date(Date.now() + config.refreshTokenTtlDays * 86400_000);
  const result = await pool.query(
    `INSERT INTO sessions (user_id, device_id, refresh_token_hash, expires_at, last_seen_at)
     VALUES ($1, $2, $3, $4, now()) RETURNING id`,
    [userId, deviceId, refreshHash, expiresAt],
  );
  const sessionId = result.rows[0].id as string;
  return { accessToken: await signAccessToken(sessionId, userId), refreshToken, expiresAt };
}

export async function rotateSession(refreshToken: string) {
  const hash = sha256(refreshToken);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const current = await client.query(
      `SELECT s.id, s.user_id, s.device_id, s.expires_at, s.revoked_at,
              d.revoked_at AS device_revoked_at
         FROM sessions s
         LEFT JOIN devices d ON d.id = s.device_id
        WHERE s.refresh_token_hash = $1 FOR UPDATE`,
      [hash],
    );
    const row = current.rows[0];
    if (!row || row.revoked_at || row.device_revoked_at || new Date(row.expires_at).getTime() <= Date.now()) {
      throw new Error('Invalid refresh session');
    }

    const nextRefresh = randomToken(48);
    const nextHash = sha256(nextRefresh);
    const nextExpires = new Date(Date.now() + config.refreshTokenTtlDays * 86400_000);
    const inserted = await client.query(
      `INSERT INTO sessions (user_id, device_id, refresh_token_hash, expires_at, last_seen_at)
       VALUES ($1, $2, $3, $4, now()) RETURNING id`,
      [row.user_id, row.device_id, nextHash, nextExpires],
    );
    await client.query(
      `UPDATE sessions SET revoked_at = now(), replaced_by_session_id = $2, last_seen_at = now()
        WHERE id = $1 AND revoked_at IS NULL`,
      [row.id, inserted.rows[0].id],
    );
    if (row.device_id) {
      await client.query(`UPDATE devices SET last_seen_at = now() WHERE id = $1 AND revoked_at IS NULL`, [row.device_id]);
    }
    await client.query('COMMIT');

    return { accessToken: await signAccessToken(inserted.rows[0].id, row.user_id), refreshToken: nextRefresh, expiresAt: nextExpires };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function revokeByQuery(query: string, params: unknown[]): Promise<number> {
  const result = await pool.query(query, params);
  return Number(result.rowCount ?? 0);
}

export async function revokeSession(sessionId: string, userId: string): Promise<boolean> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `UPDATE sessions SET revoked_at = now(), last_seen_at = now()
        WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
        RETURNING device_id`,
      [sessionId, userId],
    );
    if (!result.rows[0]) {
      await client.query('ROLLBACK');
      return false;
    }
    const deviceId = result.rows[0].device_id as string | null;
    if (deviceId) {
      await client.query(
        `UPDATE devices d SET revoked_at = now()
          WHERE d.id = $1
            AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.device_id = d.id AND s.revoked_at IS NULL AND s.expires_at > now())`,
        [deviceId],
      );
      await client.query(
        `UPDATE notification_devices SET enabled = FALSE, revoked_at = now(), updated_at = now()
          WHERE device_id = $1 AND user_id = $2`,
        [deviceId, userId],
      );
    }
    await client.query('COMMIT');
    return true;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function revokeAllOtherSessions(userId: string, currentSessionId: string): Promise<number> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `UPDATE sessions SET revoked_at = now(), last_seen_at = now()
        WHERE user_id = $1 AND id <> $2 AND revoked_at IS NULL
        RETURNING device_id`,
      [userId, currentSessionId],
    );
    await client.query(
      `UPDATE devices d SET revoked_at = now()
        WHERE d.user_id = $1
          AND d.id IN (SELECT device_id FROM (SELECT DISTINCT device_id FROM sessions WHERE user_id = $1 AND revoked_at IS NOT NULL AND device_id IS NOT NULL) x)
          AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.device_id = d.id AND s.revoked_at IS NULL AND s.expires_at > now())`,
      [userId],
    );
    await client.query(
      `UPDATE notification_devices nd SET enabled = FALSE, revoked_at = now(), updated_at = now()
        WHERE nd.user_id = $1 AND nd.device_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.device_id = nd.device_id AND s.revoked_at IS NULL AND s.expires_at > now())`,
      [userId],
    );
    await client.query('COMMIT');
    return Number(result.rowCount ?? 0);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function revokeAllSessions(userId: string): Promise<number> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const sessions = await client.query(`UPDATE sessions SET revoked_at = now(), last_seen_at = now() WHERE user_id = $1 AND revoked_at IS NULL RETURNING device_id`, [userId]);
    await client.query(`UPDATE devices SET revoked_at = now() WHERE user_id = $1`, [userId]);
    await client.query(`UPDATE notification_devices SET enabled = FALSE, revoked_at = now(), updated_at = now() WHERE user_id = $1`, [userId]);
    await client.query('COMMIT');
    return Number(sessions.rowCount ?? 0);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function revokeSessionLegacy(sessionId: string): Promise<void> {
  await revokeByQuery('UPDATE sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL', [sessionId]);
}
