import { DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { pool } from '../db/pool.js';
import { storageBucket, storageClient } from '../config/storage.js';

async function assertMember(userId: string, messageId: string) {
  const r = await pool.query(
    `SELECT m.id,m.conversation_id,m.sender_id,m.expires_at,m.deleted_at
       FROM messages m JOIN conversation_members cm ON cm.conversation_id=m.conversation_id
      WHERE m.id=$1 AND cm.user_id=$2 AND cm.left_at IS NULL`,
    [messageId, userId],
  );
  if (!r.rows[0]) throw new Error('FORBIDDEN');
  return r.rows[0];
}

export async function markDelivered(userId: string, messageId: string) {
  const message = await assertMember(userId, messageId);
  if (message.sender_id === userId) return;
  await pool.query(
    `INSERT INTO message_receipts(message_id,user_id,delivered_at)
     VALUES($1,$2,now())
     ON CONFLICT(message_id,user_id) DO UPDATE
       SET delivered_at=COALESCE(message_receipts.delivered_at,EXCLUDED.delivered_at), updated_at=now()` ,
    [messageId, userId],
  );
}

export async function markRead(userId: string, messageId: string) {
  const message = await assertMember(userId, messageId);
  if (message.sender_id === userId) return;
  const pref = await pool.query('SELECT read_receipts_enabled FROM privacy_settings WHERE user_id=$1', [userId]);
  if (pref.rows[0]?.read_receipts_enabled === false) return;
  await pool.query(
    `INSERT INTO message_receipts(message_id,user_id,delivered_at,read_at)
     VALUES($1,$2,now(),now())
     ON CONFLICT(message_id,user_id) DO UPDATE
       SET delivered_at=COALESCE(message_receipts.delivered_at,now()), read_at=COALESCE(message_receipts.read_at,now()), updated_at=now()`,
    [messageId, userId],
  );
}

export async function listReceipts(userId: string, messageId: string) {
  const message = await assertMember(userId, messageId);
  if (message.sender_id !== userId) throw new Error('FORBIDDEN');
  const r = await pool.query(
    `SELECT mr.user_id,mr.delivered_at,mr.read_at
       FROM message_receipts mr JOIN conversation_members cm ON cm.user_id=mr.user_id AND cm.conversation_id=$2 AND cm.left_at IS NULL
      WHERE mr.message_id=$1 ORDER BY mr.user_id`,
    [messageId, message.conversation_id],
  );
  return r.rows;
}

export async function expireMessages(limit = 500) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const r = await client.query(
      `SELECT m.id,a.object_key
         FROM messages m LEFT JOIN attachments a ON a.message_id=m.id AND a.deleted_at IS NULL
        WHERE m.expires_at IS NOT NULL AND m.expires_at<=now() AND m.deleted_at IS NULL
        ORDER BY m.expires_at ASC LIMIT $1 FOR UPDATE OF m SKIP LOCKED`,
      [Math.min(Math.max(limit, 1), 1000)],
    );
    if (r.rows.length === 0) { await client.query('COMMIT'); return 0; }
    const ids = r.rows.map((x) => x.id);
    await client.query('UPDATE messages SET deleted_at=COALESCE(deleted_at,now()), body=NULL WHERE id=ANY($1::uuid[])', [ids]);
    await client.query('UPDATE attachments SET deleted_at=now() WHERE message_id=ANY($1::uuid[]) AND deleted_at IS NULL', [ids]);
    await client.query('COMMIT');
    const keys = r.rows.map((x) => x.object_key).filter(Boolean);
    if (keys.length) {
      await storageClient.send(new DeleteObjectsCommand({ Bucket: storageBucket, Delete: { Objects: keys.map((Key) => ({ Key })), Quiet: true } })).catch(() => undefined);
    }
    return ids.length;
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}
