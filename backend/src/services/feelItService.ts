import { pool } from '../db/pool.js';
import { DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { storageBucket, storageClient } from '../config/storage.js';
import { queueNotification } from './notificationService.js';

const EXPIRY_HOURS = 24;
const MAX_TEXT = 10000;
const MAX_REPLY = 4000;
const VALID_REACTIONS = /^[\p{L}\p{N}\p{Emoji_Presentation}\p{Extended_Pictographic}\s_.!?+-]{1,32}$/u;

export type FeelItVisibility = 'contacts' | 'selected' | 'exclude';
export type FeelItCreateInput = { text?: string; attachmentId?: string; visibility: FeelItVisibility; userIds: string[] };

export function validateFeelItInput(input: FeelItCreateInput): string | null {
  const text = input.text?.trim() || null;
  if (!text && !input.attachmentId) return 'CONTENT_REQUIRED';
  if (text && text.length > MAX_TEXT) return 'TEXT_TOO_LONG';
  if (input.visibility === 'selected' && input.userIds.length === 0) return 'RECIPIENTS_REQUIRED';
  if (input.visibility !== 'selected' && input.userIds.length > 0) return 'INVALID_RECIPIENTS';
  return null;
}

async function activeUser(client: any, userId: string) {
  const r = await client.query('SELECT id FROM users WHERE id=$1 AND deleted_at IS NULL', [userId]);
  if (!r.rows[0]) throw new Error('USER_NOT_FOUND');
}

async function canView(client: any, viewerId: string, postId: string) {
  const r = await client.query(`
    SELECT p.id, p.author_id, p.attachment_id, p.text_content, p.created_at, p.expires_at,
           v.visibility_mode
    FROM feel_it_posts p
    JOIN feel_it_visibility v ON v.post_id=p.id
    WHERE p.id=$1 AND p.deleted_at IS NULL AND p.expires_at>now()
  `, [postId]);
  const p = r.rows[0];
  if (!p) throw new Error('NOT_FOUND');
  if (p.author_id === viewerId) return p;
  const blocked = await client.query(`SELECT 1 FROM blocks WHERE (user_id=$1 AND blocked_user_id=$2) OR (user_id=$2 AND blocked_user_id=$1) LIMIT 1`, [p.author_id, viewerId]);
  if (blocked.rows[0]) throw new Error('FORBIDDEN');
  if (p.visibility_mode === 'selected') {
    const s = await client.query('SELECT 1 FROM feel_it_visibility_users WHERE post_id=$1 AND user_id=$2', [postId, viewerId]);
    if (!s.rows[0]) throw new Error('FORBIDDEN');
  } else {
    const contact = await client.query(`SELECT 1 FROM contacts WHERE user_id=$1 AND contact_user_id=$2 AND status='accepted'`, [p.author_id, viewerId]);
    if (!contact.rows[0]) throw new Error('FORBIDDEN');
    if (p.visibility_mode === 'exclude') {
      const excluded = await client.query('SELECT 1 FROM feel_it_visibility_users WHERE post_id=$1 AND user_id=$2', [postId, viewerId]);
      if (excluded.rows[0]) throw new Error('FORBIDDEN');
    }
  }
  return p;
}

function mapPost(x: any) {
  return { id:x.id, authorId:x.author_id, text:x.text_content, attachmentId:x.attachment_id, createdAt:x.created_at, expiresAt:x.expires_at };
}

export async function createFeelIt(authorId: string, input: FeelItCreateInput) {
  const validation = validateFeelItInput(input);
  if (validation) throw new Error(validation);
  const text = input.text?.trim() || null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await activeUser(client, authorId);
    const uniqueUsers = [...new Set(input.userIds)];
    if (uniqueUsers.includes(authorId)) throw new Error('INVALID_RECIPIENTS');
    for (const id of uniqueUsers) {
      await activeUser(client, id);
      const contact = await client.query(`SELECT 1 FROM contacts WHERE user_id=$1 AND contact_user_id=$2 AND status='accepted'`, [authorId, id]);
      const blocked = await client.query(`SELECT 1 FROM blocks WHERE (user_id=$1 AND blocked_user_id=$2) OR (user_id=$2 AND blocked_user_id=$1) LIMIT 1`, [authorId, id]);
      if (!contact.rows[0] || blocked.rows[0]) throw new Error('INVALID_RECIPIENTS');
    }

    if (input.attachmentId) {
      const a = await client.query(`SELECT id,owner_id,object_key,deleted_at FROM attachments WHERE id=$1`, [input.attachmentId]);
      if (!a.rows[0] || a.rows[0].owner_id !== authorId || a.rows[0].deleted_at) throw new Error('ATTACHMENT_FORBIDDEN');
    }

    const post = await client.query(`INSERT INTO feel_it_posts(author_id,attachment_id,text_content,expires_at) VALUES($1,$2,$3,now()+interval '${EXPIRY_HOURS} hours') RETURNING id,author_id,attachment_id,text_content,created_at,expires_at`, [authorId, input.attachmentId ?? null, text]);
    const row = post.rows[0];
    await client.query('INSERT INTO feel_it_visibility(post_id,visibility_mode) VALUES($1,$2)', [row.id, input.visibility]);
    if (uniqueUsers.length) {
      await client.query('INSERT INTO feel_it_visibility_users(post_id,user_id) SELECT $1,unnest($2::uuid[])', [row.id, uniqueUsers]);
    }
    await client.query('COMMIT');

    // Best-effort enqueue after commit. Push payload contains only category + post ID.
    const recipients = input.visibility === 'selected' ? uniqueUsers :
      (await pool.query(`SELECT c.contact_user_id AS user_id FROM contacts c WHERE c.user_id=$1 AND c.status='accepted' AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.user_id=$1 AND b.blocked_user_id=c.contact_user_id) OR (b.user_id=c.contact_user_id AND b.blocked_user_id=$1))`, [authorId])).rows.map(x=>x.user_id);
    await Promise.all(recipients.map(id => queueNotification(id, 'feel_it', row.id)));
    return mapPost(row);
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export async function listFeelIt(userId: string) {
  const r = await pool.query(`
    SELECT p.id,p.author_id,p.attachment_id,p.text_content,p.created_at,p.expires_at
    FROM feel_it_posts p JOIN feel_it_visibility v ON v.post_id=p.id
    WHERE p.deleted_at IS NULL AND p.expires_at>now() AND (
      p.author_id=$1 OR
      (v.visibility_mode='selected' AND EXISTS (SELECT 1 FROM feel_it_visibility_users vu WHERE vu.post_id=p.id AND vu.user_id=$1)) OR
      (v.visibility_mode IN ('contacts','exclude') AND EXISTS (SELECT 1 FROM contacts c WHERE c.user_id=p.author_id AND c.contact_user_id=$1 AND c.status='accepted') AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.user_id=p.author_id AND b.blocked_user_id=$1) OR (b.user_id=$1 AND b.blocked_user_id=p.author_id)) AND (v.visibility_mode='contacts' OR NOT EXISTS (SELECT 1 FROM feel_it_visibility_users vu WHERE vu.post_id=p.id AND vu.user_id=$1)))
    ) ORDER BY p.created_at DESC LIMIT 200`, [userId]);
  return r.rows.map(mapPost);
}

export async function markViewed(userId: string, postId: string) {
  const client = await pool.connect();
  try { await client.query('BEGIN'); await canView(client,userId,postId); await client.query(`INSERT INTO feel_it_viewers(post_id,viewer_id) VALUES($1,$2) ON CONFLICT(post_id,viewer_id) DO UPDATE SET viewed_at=now()`,[postId,userId]); await client.query('COMMIT'); }
  catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function setReaction(userId:string,postId:string,reaction:string){
  const value=reaction.trim(); if(!VALID_REACTIONS.test(value)) throw new Error('INVALID_REACTION');
  const client=await pool.connect(); try{await client.query('BEGIN');await canView(client,userId,postId);await client.query(`INSERT INTO feel_it_reactions(post_id,user_id,reaction) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO UPDATE SET reaction=EXCLUDED.reaction,created_at=now()`,[postId,userId,value]);await client.query('COMMIT');}catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
}
export async function removeReaction(userId:string,postId:string){
  const client=await pool.connect();try{await client.query('BEGIN');await canView(client,userId,postId);await client.query('DELETE FROM feel_it_reactions WHERE post_id=$1 AND user_id=$2',[postId,userId]);await client.query('COMMIT');}catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
}
export async function addReply(userId:string,postId:string,body:string){
  const value=body.trim();if(!value||value.length>MAX_REPLY)throw new Error('INVALID_REPLY');
  const client=await pool.connect();try{await client.query('BEGIN');const post=await canView(client,userId,postId);const r=await client.query(`INSERT INTO feel_it_replies(post_id,author_id,body) VALUES($1,$2,$3) RETURNING id,post_id,author_id,body,created_at`,[postId,userId,value]);await client.query('COMMIT');if(post.author_id!==userId)await queueNotification(post.author_id,'feel_it',postId);return r.rows[0];}catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
}
export async function listViewers(userId:string,postId:string){
  const client=await pool.connect();try{const p=await canView(client,userId,postId);if(p.author_id!==userId)throw new Error('FORBIDDEN');const r=await client.query(`SELECT v.viewer_id,u.display_name,u.photo_url,v.viewed_at FROM feel_it_viewers v JOIN users u ON u.id=v.viewer_id WHERE v.post_id=$1 AND u.deleted_at IS NULL ORDER BY v.viewed_at DESC`,[postId]);return r.rows.map(x=>({userId:x.viewer_id,displayName:x.display_name,avatarUrl:x.photo_url,viewedAt:x.viewed_at}));}finally{client.release();}
}
export async function deleteFeelIt(userId:string,postId:string){
  const client=await pool.connect();try{await client.query('BEGIN');const r=await client.query(`SELECT p.attachment_id,a.object_key FROM feel_it_posts p LEFT JOIN attachments a ON a.id=p.attachment_id WHERE p.id=$1 AND p.author_id=$2 AND p.deleted_at IS NULL FOR UPDATE`,[postId,userId]);if(!r.rows[0])throw new Error('NOT_FOUND');await client.query('UPDATE feel_it_posts SET deleted_at=now() WHERE id=$1',[postId]);if(r.rows[0].attachment_id)await client.query('UPDATE attachments SET deleted_at=now() WHERE id=$1',[r.rows[0].attachment_id]);await client.query('COMMIT');if(r.rows[0].object_key)await storageClient.send(new DeleteObjectCommand({Bucket:storageBucket,Key:r.rows[0].object_key})).catch(()=>undefined);}catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}}
export async function getMediaUrl(userId:string,postId:string){
  const client=await pool.connect();try{const p=await canView(client,userId,postId);if(!p.attachment_id)throw new Error('NO_ATTACHMENT');const r=await client.query(`SELECT a.object_key,a.original_name,a.byte_size,a.detected_mime FROM attachments a WHERE a.id=$1 AND a.deleted_at IS NULL`,[p.attachment_id]);if(!r.rows[0])throw new Error('NOT_FOUND');const a=r.rows[0];const url=await getSignedUrl(storageClient,new GetObjectCommand({Bucket:storageBucket,Key:a.object_key}),{expiresIn:300});return {url,expiresInSeconds:300,fileName:a.original_name,byteSize:String(a.byte_size),mime:a.detected_mime};}finally{client.release();}}
