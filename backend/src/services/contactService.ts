import crypto from 'node:crypto';
import { pool } from '../db/pool.js';
import { queueNotification } from './notificationService.js';

export type ContactRequestStatus = 'pending'|'accepted'|'declined'|'cancelled';
export type ContactDiscoveryPolicy = { discoverableByUserId:boolean; contactRequestsEnabled:boolean };

export function canSendContactRequest(policy: ContactDiscoveryPolicy, blocked:boolean): boolean {
  return policy.contactRequestsEnabled && !blocked;
}

export function generateContactQrToken(): { token:string; hash:string } {
  const token=crypto.randomBytes(32).toString('base64url');
  return { token, hash:crypto.createHash('sha256').update(token).digest('hex') };
}

export function hashContactQrToken(token: string): string {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

export function qrExpirySeconds(value:number|undefined): number {
  const n=value ?? 600;
  if (!Number.isInteger(n) || n<60 || n>86400) throw new Error('invalid_qr_expiry');
  return n;
}

export function qrMaxUses(value:number|undefined): number {
  const n=value ?? 1;
  if (!Number.isInteger(n) || n<1 || n>100) throw new Error('invalid_qr_max_uses');
  return n;
}

export function normalizeUserId(value:string): string {
  const v=value.trim();
  if (v.length<1 || v.length>128) throw new Error('invalid_user_id');
  return v;
}

function pairLock(a: string, b: string): string {
  return [a,b].sort().join(':');
}

async function lockPair(client: any, a: string, b: string) {
  await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [pairLock(a,b)]);
}

async function ensureActiveUser(client: any, userId: string) {
  const r=await client.query('SELECT id, display_name, photo_url FROM users WHERE id=$1 AND deleted_at IS NULL',[userId]);
  if(!r.rows[0]) throw new Error('USER_NOT_FOUND');
  return r.rows[0];
}

async function isBlocked(client: any, a: string, b: string): Promise<boolean> {
  const r=await client.query('SELECT 1 FROM blocks WHERE (user_id=$1 AND blocked_user_id=$2) OR (user_id=$2 AND blocked_user_id=$1) LIMIT 1',[a,b]);
  return !!r.rows[0];
}

export async function listContacts(userId: string) {
  const r=await pool.query(`SELECT u.id, u.display_name, u.photo_url, c.created_at
    FROM contacts c JOIN users u ON u.id=c.contact_user_id
    WHERE c.user_id=$1 AND c.status='accepted' AND u.deleted_at IS NULL
    ORDER BY c.created_at DESC`,[userId]);
  return r.rows.map(x=>({id:x.id,displayName:x.display_name,avatarUrl:x.photo_url,createdAt:x.created_at}));
}

export async function listContactRequests(userId: string) {
  const r=await pool.query(`SELECT cr.id, cr.requester_id, cr.recipient_id, cr.status, cr.created_at,
    u.display_name, u.photo_url
    FROM contact_requests cr JOIN users u ON u.id=CASE WHEN cr.requester_id=$1 THEN cr.recipient_id ELSE cr.requester_id END
    WHERE (cr.requester_id=$1 OR cr.recipient_id=$1) AND cr.status='pending' AND u.deleted_at IS NULL
    ORDER BY cr.created_at DESC`,[userId]);
  return r.rows.map(x=>({id:x.id,userId:x.requester_id===userId?x.recipient_id:x.requester_id,direction:x.recipient_id===userId?'incoming':'outgoing',status:x.status,displayName:x.display_name,avatarUrl:x.photo_url,createdAt:x.created_at}));
}

export async function sendContactRequest(requesterId: string, recipientId: string) {
  if(requesterId===recipientId) throw new Error('SELF_CONTACT');
  const client=await pool.connect();
  try {
    await client.query('BEGIN'); await lockPair(client,requesterId,recipientId);
    await ensureActiveUser(client,requesterId); await ensureActiveUser(client,recipientId);
    if(await isBlocked(client,requesterId,recipientId)) throw new Error('BLOCKED');
    const privacy=await client.query('SELECT contact_requests_enabled FROM privacy_settings WHERE user_id=$1',[recipientId]);
    if(privacy.rows[0] && !privacy.rows[0].contact_requests_enabled) throw new Error('REQUESTS_DISABLED');
    const existing=await client.query(`SELECT status FROM contacts WHERE user_id=$1 AND contact_user_id=$2 AND status='accepted'`,[requesterId,recipientId]);
    if(existing.rows[0]) throw new Error('ALREADY_CONTACT');
    const reverse=await client.query(`SELECT status FROM contact_requests WHERE requester_id=$2 AND recipient_id=$1 AND status='pending'`,[requesterId,recipientId]);
    if(reverse.rows[0]) throw new Error('INCOMING_REQUEST_EXISTS');
    const r=await client.query(`INSERT INTO contact_requests(requester_id,recipient_id,status) VALUES($1,$2,'pending') RETURNING id,created_at`,[requesterId,recipientId]);
    await client.query('COMMIT'); await queueNotification(recipientId,'contact_request',r.rows[0].id); return {requestId:r.rows[0].id,createdAt:r.rows[0].created_at};
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

async function resolveRequest(client:any, actorId:string, requestId:string, incoming:boolean) {
  const r=await client.query(`SELECT id,requester_id,recipient_id,status FROM contact_requests WHERE id=$1 FOR UPDATE`,[requestId]);
  const row=r.rows[0]; if(!row) throw new Error('REQUEST_NOT_FOUND');
  if(row.status!=='pending') throw new Error('REQUEST_NOT_PENDING');
  if(incoming ? row.recipient_id!==actorId : row.requester_id!==actorId) throw new Error('FORBIDDEN');
  return row;
}

export async function acceptContactRequest(userId:string, requestId:string) {
  const client=await pool.connect();
  try { await client.query('BEGIN'); const row=await resolveRequest(client,userId,requestId,true); await lockPair(client,row.requester_id,row.recipient_id);
    if(await isBlocked(client,row.requester_id,row.recipient_id)) throw new Error('BLOCKED');
    await client.query(`INSERT INTO contacts(user_id,contact_user_id,status) VALUES($1,$2,'accepted'),($2,$1,'accepted') ON CONFLICT(user_id,contact_user_id) DO UPDATE SET status='accepted'`,[row.requester_id,row.recipient_id]);
    await client.query(`UPDATE contact_requests SET status='accepted',responded_at=now(),updated_at=now() WHERE id=$1`,[requestId]);
    await client.query('COMMIT'); return {status:'accepted'};
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function declineContactRequest(userId:string, requestId:string) {
  const r=await pool.query(`UPDATE contact_requests SET status='declined',responded_at=now(),updated_at=now() WHERE id=$1 AND recipient_id=$2 AND status='pending' RETURNING id`,[requestId,userId]);
  if(!r.rows[0]) throw new Error('REQUEST_NOT_FOUND'); return {status:'declined'};
}

export async function cancelContactRequest(userId:string, requestId:string) {
  const r=await pool.query(`UPDATE contact_requests SET status='cancelled',responded_at=now(),updated_at=now() WHERE id=$1 AND requester_id=$2 AND status='pending' RETURNING id`,[requestId,userId]);
  if(!r.rows[0]) throw new Error('REQUEST_NOT_FOUND'); return {status:'cancelled'};
}

export async function removeContact(userId:string, contactUserId:string) {
  const client=await pool.connect(); try {await client.query('BEGIN'); await lockPair(client,userId,contactUserId);
    const r=await client.query(`DELETE FROM contacts WHERE (user_id=$1 AND contact_user_id=$2) OR (user_id=$2 AND contact_user_id=$1) RETURNING user_id`,[userId,contactUserId]);
    if(!r.rows.length) throw new Error('NOT_FOUND'); await client.query('COMMIT');
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function discoverUser(actorId:string, targetId:string) {
  if(actorId===targetId) throw new Error('SELF_CONTACT');
  const r=await pool.query(`SELECT u.id,u.display_name,u.photo_url FROM users u
    JOIN privacy_settings p ON p.user_id=u.id
    WHERE u.id=$1 AND u.deleted_at IS NULL AND p.discoverable_by_user_id=true`,[targetId]);
  if(!r.rows[0]) throw new Error('USER_NOT_FOUND');
  if(await isBlocked(pool,actorId,targetId)) throw new Error('USER_NOT_FOUND');
  return {id:r.rows[0].id,displayName:r.rows[0].display_name,avatarUrl:r.rows[0].photo_url};
}

export async function createContactQr(userId:string, expiresInSeconds=600, maxUses=1) {
  const expires=qrExpirySeconds(expiresInSeconds), uses=qrMaxUses(maxUses), generated=generateContactQrToken();
  const r=await pool.query(`INSERT INTO contact_qr_tokens(user_id,token_hash,expires_at,max_uses) VALUES($1,$2,now()+($3::int * interval '1 second'),$4) RETURNING id,expires_at,max_uses`,[userId,generated.hash,expires,uses]);
  return {id:r.rows[0].id,token:generated.token,expiresAt:r.rows[0].expires_at,maxUses:r.rows[0].max_uses};
}

export async function consumeContactQr(userId:string, token:string) {
  const client=await pool.connect();
  try {await client.query('BEGIN');
    const hash=hashContactQrToken(token);
    const q=await client.query(`SELECT id,user_id,max_uses,uses,expires_at FROM contact_qr_tokens WHERE token_hash=$1 AND revoked_at IS NULL AND expires_at>now() FOR UPDATE`,[hash]);
    const row=q.rows[0]; if(!row || row.uses>=row.max_uses) throw new Error('INVALID_QR_TOKEN');
    const ownerId=row.user_id as string; if(ownerId===userId) throw new Error('SELF_CONTACT');
    await lockPair(client,userId,ownerId); await ensureActiveUser(client,userId); await ensureActiveUser(client,ownerId);
    if(await isBlocked(client,userId,ownerId)) throw new Error('BLOCKED');
    await client.query(`INSERT INTO contacts(user_id,contact_user_id,status) VALUES($1,$2,'accepted'),($2,$1,'accepted') ON CONFLICT(user_id,contact_user_id) DO UPDATE SET status='accepted'`,[userId,ownerId]);
    await client.query(`UPDATE contact_qr_tokens SET uses=uses+1,revoked_at=CASE WHEN uses+1>=max_uses THEN now() ELSE revoked_at END WHERE id=$1`,[row.id]);
    await client.query('COMMIT'); return {contact:await getContact(userId,ownerId)};
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

async function getContact(userId:string, contactUserId:string) {
  const r=await pool.query(`SELECT u.id,u.display_name,u.photo_url,c.created_at FROM contacts c JOIN users u ON u.id=c.contact_user_id WHERE c.user_id=$1 AND c.contact_user_id=$2 AND c.status='accepted'`,[userId,contactUserId]);
  if(!r.rows[0]) throw new Error('NOT_FOUND'); const x=r.rows[0]; return {id:x.id,displayName:x.display_name,avatarUrl:x.photo_url,createdAt:x.created_at};
}
