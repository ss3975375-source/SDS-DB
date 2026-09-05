import { DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { pool } from '../db/pool.js';
import { storageBucket, storageClient } from '../config/storage.js';

export const DELETION_GRACE_MS = 24 * 60 * 60_000;

const PRIVACY_KEYS = [
  'discoverableByUserId',
  'contactRequestsEnabled',
  'readReceiptsEnabled',
  'typingIndicatorsEnabled',
  'presenceEnabled',
  'feelItDefaultVisibility',
] as const;

export type PrivacySettings = {
  discoverableByUserId: boolean;
  contactRequestsEnabled: boolean;
  readReceiptsEnabled: boolean;
  typingIndicatorsEnabled: boolean;
  presenceEnabled: boolean;
  feelItDefaultVisibility: 'contacts' | 'selected' | 'exclude';
};

export async function getPrivacySettings(userId: string): Promise<PrivacySettings> {
  const r = await pool.query(`
    INSERT INTO privacy_settings(user_id) VALUES($1)
    ON CONFLICT(user_id) DO NOTHING
    RETURNING discoverable_by_user_id, contact_requests_enabled, read_receipts_enabled,
      typing_indicators_enabled, presence_enabled, feel_it_default_visibility
  `, [userId]);
  const row = r.rows[0] ?? (await pool.query(`
    SELECT discoverable_by_user_id, contact_requests_enabled, read_receipts_enabled,
      typing_indicators_enabled, presence_enabled, feel_it_default_visibility
    FROM privacy_settings WHERE user_id=$1
  `, [userId])).rows[0];
  if (!row) throw new Error('USER_NOT_FOUND');
  return mapPrivacy(row);
}

export async function updatePrivacySettings(userId: string, patch: Partial<PrivacySettings>): Promise<PrivacySettings> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await client.query('SELECT 1 FROM users WHERE id=$1 AND deleted_at IS NULL', [userId]);
    if (!user.rows[0]) throw new Error('USER_NOT_FOUND');
    const current = await client.query(`SELECT * FROM privacy_settings WHERE user_id=$1 FOR UPDATE`, [userId]);
    const row = current.rows[0] ?? {
      discoverable_by_user_id: true,
      contact_requests_enabled: true,
      read_receipts_enabled: true,
      typing_indicators_enabled: true,
      presence_enabled: false,
      feel_it_default_visibility: 'contacts',
    };
    const next: PrivacySettings = {
      discoverableByUserId: patch.discoverableByUserId ?? row.discoverable_by_user_id,
      contactRequestsEnabled: patch.contactRequestsEnabled ?? row.contact_requests_enabled,
      readReceiptsEnabled: patch.readReceiptsEnabled ?? row.read_receipts_enabled,
      typingIndicatorsEnabled: patch.typingIndicatorsEnabled ?? row.typing_indicators_enabled,
      presenceEnabled: patch.presenceEnabled ?? row.presence_enabled,
      feelItDefaultVisibility: patch.feelItDefaultVisibility ?? row.feel_it_default_visibility,
    };
    await client.query(`
      INSERT INTO privacy_settings(user_id,discoverable_by_user_id,contact_requests_enabled,
        read_receipts_enabled,typing_indicators_enabled,presence_enabled,feel_it_default_visibility)
      VALUES($1,$2,$3,$4,$5,$6,$7)
      ON CONFLICT(user_id) DO UPDATE SET
        discoverable_by_user_id=EXCLUDED.discoverable_by_user_id,
        contact_requests_enabled=EXCLUDED.contact_requests_enabled,
        read_receipts_enabled=EXCLUDED.read_receipts_enabled,
        typing_indicators_enabled=EXCLUDED.typing_indicators_enabled,
        presence_enabled=EXCLUDED.presence_enabled,
        feel_it_default_visibility=EXCLUDED.feel_it_default_visibility,
        updated_at=now()
    `, [userId, next.discoverableByUserId, next.contactRequestsEnabled, next.readReceiptsEnabled,
      next.typingIndicatorsEnabled, next.presenceEnabled, next.feelItDefaultVisibility]);
    await client.query('COMMIT');
    return next;
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

function mapPrivacy(row: any): PrivacySettings {
  return {
    discoverableByUserId: row.discoverable_by_user_id,
    contactRequestsEnabled: row.contact_requests_enabled,
    readReceiptsEnabled: row.read_receipts_enabled,
    typingIndicatorsEnabled: row.typing_indicators_enabled,
    presenceEnabled: row.presence_enabled,
    feelItDefaultVisibility: row.feel_it_default_visibility,
  };
}

export function validatePrivacyPatch(input: Record<string, unknown>): Partial<PrivacySettings> {
  const unknown = Object.keys(input).filter(k => !(PRIVACY_KEYS as readonly string[]).includes(k));
  if (unknown.length) throw new Error('UNKNOWN_PRIVACY_SETTING');
  const boolKeys = PRIVACY_KEYS.slice(0, 5);
  for (const key of boolKeys) if (key in input && typeof input[key] !== 'boolean') throw new Error('INVALID_PRIVACY_SETTING');
  if ('feelItDefaultVisibility' in input && !['contacts','selected','exclude'].includes(String(input.feelItDefaultVisibility))) {
    throw new Error('INVALID_PRIVACY_SETTING');
  }
  return input as Partial<PrivacySettings>;
}

export async function requestAccountDeletion(userId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await client.query(`SELECT id,deleted_at,deletion_requested_at FROM users WHERE id=$1 FOR UPDATE`, [userId]);
    if (!user.rows[0]) throw new Error('USER_NOT_FOUND');
    if (user.rows[0].deleted_at) throw new Error('ACCOUNT_ALREADY_DELETED');
    const existing = await client.query(`SELECT id,scheduled_for,status FROM account_deletion_jobs WHERE user_id=$1 AND status IN ('pending','processing') ORDER BY requested_at DESC LIMIT 1`, [userId]);
    if (existing.rows[0]) { await client.query('COMMIT'); return {jobId: existing.rows[0].id, scheduledFor: existing.rows[0].scheduled_for, status: existing.rows[0].status}; }
    const scheduled = new Date(Date.now() + DELETION_GRACE_MS);
    const job = await client.query(`INSERT INTO account_deletion_jobs(user_id,requested_at,scheduled_for,status) VALUES($1,now(),$2,'pending') RETURNING id,scheduled_for,status`, [userId, scheduled]);
    await client.query(`UPDATE users SET deletion_requested_at=now(),updated_at=now() WHERE id=$1`, [userId]);
    await client.query(`UPDATE sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE user_id=$1`, [userId]);
    await client.query('COMMIT');
    return {jobId: job.rows[0].id, scheduledFor: job.rows[0].scheduled_for, status: job.rows[0].status};
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function processPendingAccountDeletions(limit = 10): Promise<number> {
  let processed = 0;
  for (;;) {
    const client = await pool.connect();
    let job: any;
    try {
      await client.query('BEGIN');
      const r = await client.query(`SELECT id,user_id FROM account_deletion_jobs WHERE status='pending' AND scheduled_for<=now() ORDER BY scheduled_for LIMIT 1 FOR UPDATE SKIP LOCKED`);
      if (!r.rows[0]) { await client.query('COMMIT'); break; }
      job = r.rows[0];
      await client.query(`UPDATE account_deletion_jobs SET status='processing',started_at=now(),failure_code=NULL WHERE id=$1`, [job.id]);
      const keys = await client.query(`
        SELECT object_key AS key FROM attachments WHERE owner_id=$1 AND object_key IS NOT NULL AND deleted_at IS NULL
        UNION
        SELECT object_key AS key FROM feel_it_posts WHERE author_id=$1 AND object_key IS NOT NULL AND deleted_at IS NULL
        UNION
        SELECT object_key AS key FROM file_uploads WHERE user_id=$1 AND object_key IS NOT NULL
      `, [job.user_id]);
      for (const row of keys.rows) await client.query(`INSERT INTO account_deletion_objects(job_id,object_key) VALUES($1,$2) ON CONFLICT DO NOTHING`, [job.id, row.key]);
      await client.query('COMMIT');
    } catch (e) { await client.query('ROLLBACK'); client.release(); throw e; } finally { client.release(); }

    try {
      const objects = await pool.query(`SELECT id,object_key FROM account_deletion_objects WHERE job_id=$1 AND deleted_at IS NULL ORDER BY id LIMIT 1000`, [job.id]);
      if (objects.rows.length) {
        await storageClient.send(new DeleteObjectsCommand({Bucket: storageBucket, Delete: {Objects: objects.rows.map((x:any) => ({Key:x.object_key}))}}));
        await pool.query(`UPDATE account_deletion_objects SET deleted_at=now() WHERE job_id=$1 AND id=ANY($2::uuid[])`, [job.id, objects.rows.map((x:any)=>x.id)]);
      }
      const remaining = await pool.query(`SELECT 1 FROM account_deletion_objects WHERE job_id=$1 AND deleted_at IS NULL LIMIT 1`, [job.id]);
      if (remaining.rows[0]) continue;
      await finalizeDeletion(job.id, job.user_id);
      processed++;
      if (processed >= limit) break;
    } catch (e) {
      await pool.query(`UPDATE account_deletion_jobs SET status='failed',failure_code=$2 WHERE id=$1`, [job.id, e instanceof Error ? 'OBJECT_CLEANUP_FAILED' : 'UNKNOWN']);
      throw e;
    }
  }
  return processed;
}

async function finalizeDeletion(jobId: string, userId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Delete data owned by the account. Shared messages authored by this user are removed
    // because the schema has no anonymous sender representation; other users' messages remain.
    await client.query(`DELETE FROM messages WHERE sender_id=$1`, [userId]);
    await client.query(`DELETE FROM groups WHERE created_by=$1`, [userId]);
    await client.query(`DELETE FROM contacts WHERE user_id=$1 OR contact_user_id=$1`, [userId]);
    await client.query(`DELETE FROM contact_requests WHERE requester_id=$1 OR recipient_id=$1`, [userId]);
    await client.query(`DELETE FROM blocks WHERE user_id=$1 OR blocked_user_id=$1`, [userId]);
    await client.query(`DELETE FROM feel_it_posts WHERE author_id=$1`, [userId]);
    await client.query(`DELETE FROM notifications WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM notification_devices WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM privacy_settings WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM file_usage_daily WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM file_upload_parts WHERE upload_id IN (SELECT id FROM file_uploads WHERE user_id=$1)`, [userId]);
    await client.query(`DELETE FROM file_uploads WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM devices WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM sessions WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM reports WHERE reporter_id=$1`, [userId]);
    await client.query(`UPDATE reports SET reported_user_id=NULL WHERE reported_user_id=$1`, [userId]);
    await client.query(`UPDATE users SET deleted_at=now(),deletion_requested_at=COALESCE(deletion_requested_at,now()),display_name='Deleted user',email='deleted+'||id::text||'@invalid.local',photo_url=NULL,updated_at=now() WHERE id=$1`, [userId]);
    await client.query(`UPDATE account_deletion_jobs SET status='completed',completed_at=now() WHERE id=$1`, [jobId]);
    await client.query('DELETE FROM account_deletion_objects WHERE job_id=$1', [jobId]);
    await client.query('COMMIT');
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function cancelAccountDeletion(userId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const r = await client.query(`SELECT id FROM account_deletion_jobs WHERE user_id=$1 AND status='pending' AND scheduled_for>now() ORDER BY requested_at DESC LIMIT 1 FOR UPDATE`, [userId]);
    if (!r.rows[0]) throw new Error('DELETION_NOT_CANCELLABLE');
    await client.query(`UPDATE account_deletion_jobs SET status='cancelled' WHERE id=$1`, [r.rows[0].id]);
    await client.query(`UPDATE users SET deletion_requested_at=NULL,updated_at=now() WHERE id=$1`, [userId]);
    await client.query('COMMIT');
    return {status:'cancelled'};
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function createReport(reporterId: string, input: {reportedUserId?:string;messageId?:string;conversationId?:string;attachmentId?:string;reason:string;details?:string}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const actor = await client.query(`SELECT 1 FROM users WHERE id=$1 AND deleted_at IS NULL`, [reporterId]);
    if (!actor.rows[0]) throw new Error('USER_NOT_FOUND');
    const targets = [input.reportedUserId,input.messageId,input.conversationId,input.attachmentId].filter(Boolean);
    if (targets.length !== 1) throw new Error('INVALID_TARGET');
    if (input.reportedUserId) {
      const target = await client.query(`SELECT id FROM users WHERE id=$1 AND deleted_at IS NULL`, [input.reportedUserId]);
      if (!target.rows[0] || input.reportedUserId === reporterId) throw new Error('REPORT_TARGET_UNAVAILABLE');
    } else if (input.conversationId) {
      const member = await client.query(`SELECT 1 FROM conversation_members WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [input.conversationId,reporterId]);
      if (!member.rows[0]) throw new Error('REPORT_TARGET_UNAVAILABLE');
    } else if (input.messageId) {
      const msg = await client.query(`SELECT 1 FROM messages m JOIN conversation_members cm ON cm.conversation_id=m.conversation_id WHERE m.id=$1 AND cm.user_id=$2 AND cm.left_at IS NULL`, [input.messageId,reporterId]);
      if (!msg.rows[0]) throw new Error('REPORT_TARGET_UNAVAILABLE');
    } else if (input.attachmentId) {
      const a = await client.query(`SELECT 1 FROM attachments a JOIN messages m ON m.id=a.message_id JOIN conversation_members cm ON cm.conversation_id=m.conversation_id WHERE a.id=$1 AND a.deleted_at IS NULL AND cm.user_id=$2 AND cm.left_at IS NULL`, [input.attachmentId,reporterId]);
      if (!a.rows[0]) throw new Error('REPORT_TARGET_UNAVAILABLE');
    }
    const r = await client.query(`INSERT INTO reports(reporter_id,reported_user_id,message_id,conversation_id,attachment_id,reason,details) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id,created_at,status`, [reporterId,input.reportedUserId??null,input.messageId??null,input.conversationId??null,input.attachmentId??null,input.reason.trim(),input.details?.trim()||null]);
    await client.query('COMMIT');
    return r.rows[0];
  } catch(e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function getDeletionStatus(userId: string) {
  const r = await pool.query(`SELECT id,scheduled_for,status,requested_at FROM account_deletion_jobs WHERE user_id=$1 ORDER BY requested_at DESC LIMIT 1`, [userId]);
  return r.rows[0] ? {jobId:r.rows[0].id,scheduledFor:r.rows[0].scheduled_for,status:r.rows[0].status,requestedAt:r.rows[0].requested_at} : null;
}
