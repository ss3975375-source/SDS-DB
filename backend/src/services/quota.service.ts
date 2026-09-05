import { pool } from '../db/pool.js';
export const DIRECT_DAILY_LIMIT = 12n * 1024n * 1024n * 1024n;
export const GROUP_DAILY_LIMIT = 24n * 1024n * 1024n * 1024n;

export async function reserveUploadQuota(userId: string, conversationId: string, bytes: bigint): Promise<{remaining: bigint; usageDate: string}> {
  if (bytes <= 0n) throw new Error('INVALID_BYTES');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const conversation = await client.query(`SELECT c.kind, EXISTS(SELECT 1 FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.user_id=$1 AND cm.left_at IS NULL) AS is_member FROM conversations c WHERE c.id=$2 AND c.deleted_at IS NULL`, [userId, conversationId]);
    const row = conversation.rows[0];
    if (!row || !row.is_member) throw new Error('FORBIDDEN');
    const scope = row.kind as 'direct'|'group';
    const limit = scope === 'direct' ? DIRECT_DAILY_LIMIT : GROUP_DAILY_LIMIT;
    const usage = await client.query(`INSERT INTO file_usage_daily(user_id,usage_date,conversation_id,scope,bytes_used,reserved_bytes) VALUES($1,CURRENT_DATE,$2,$3,0,0) ON CONFLICT(user_id,usage_date,conversation_id) DO UPDATE SET bytes_used=file_usage_daily.bytes_used RETURNING usage_date,bytes_used,reserved_bytes`, [userId, conversationId, scope]);
    const used = BigInt(usage.rows[0].bytes_used), reserved = BigInt(usage.rows[0].reserved_bytes);
    if (used + reserved + bytes > limit) throw new Error('QUOTA_EXCEEDED');
    const next = await client.query(`UPDATE file_usage_daily SET reserved_bytes=reserved_bytes+$1 WHERE user_id=$2 AND usage_date=CURRENT_DATE AND conversation_id=$3 RETURNING bytes_used,reserved_bytes,usage_date`, [bytes.toString(), userId, conversationId]);
    await client.query('COMMIT');
    return { remaining: limit - BigInt(next.rows[0].bytes_used) - BigInt(next.rows[0].reserved_bytes), usageDate: next.rows[0].usage_date.toISOString().slice(0,10) };
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function releaseUploadQuota(userId: string, conversationId: string, usageDate: string, bytes: bigint): Promise<void> {
  if (bytes <= 0n) return;
  await pool.query(`UPDATE file_usage_daily SET reserved_bytes=GREATEST(0,reserved_bytes-$1) WHERE user_id=$2 AND usage_date=$3::date AND conversation_id=$4`, [bytes.toString(), userId, usageDate, conversationId]);
}
