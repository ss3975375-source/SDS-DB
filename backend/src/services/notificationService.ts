import crypto from 'node:crypto';
import { pool } from '../db/pool.js';
import { config } from '../config/env.js';
import { decryptPushToken, encryptPushToken } from './pushCrypto.js';
import { isInvalidFcmTokenError, sendFcm } from './pushProvider.js';

export type NotificationCategory = 'message'|'group'|'contact_request'|'feel_it';
export type PrivacySafeNotification = { title:string; body:string; category:NotificationCategory; eventId?:string };

export function hashPushToken(token:string): string { return crypto.createHash('sha256').update(token,'utf8').digest('hex'); }
export function validatePushToken(token:string): boolean { return token.trim().length >= 20 && token.length <= 4096; }
export function buildPrivacySafeNotification(category:NotificationCategory,eventId?:string):PrivacySafeNotification {
  const copy:Record<NotificationCategory,[string,string]>={message:['New message','You have a new message'],group:['New group activity','There is new activity in a group'],contact_request:['New contact request','You have a new contact request'],feel_it:['New Feel It','You have new Feel It activity']};
  const [title,body]=copy[category]; return eventId===undefined?{title,body,category}:{title,body,category,eventId};
}

const prefColumn:Record<NotificationCategory,string>={message:'message_enabled',group:'group_enabled',contact_request:'contact_request_enabled',feel_it:'feel_it_enabled'};

export async function getPreferences(userId:string) {
  const r=await pool.query(`INSERT INTO notification_preferences(user_id) VALUES($1) ON CONFLICT(user_id) DO NOTHING RETURNING *`,[userId]);
  if(r.rows[0]) return mapPreferences(r.rows[0]);
  const x=await pool.query('SELECT * FROM notification_preferences WHERE user_id=$1',[userId]); return mapPreferences(x.rows[0]);
}
function mapPreferences(x:any){ return {pushEnabled:x.push_enabled,messageEnabled:x.message_enabled,groupEnabled:x.group_enabled,contactRequestEnabled:x.contact_request_enabled,feelItEnabled:x.feel_it_enabled,showPreview:x.show_preview}; }

export async function updatePreferences(userId:string, patch:Record<string,unknown>) {
  const current=await getPreferences(userId);
  const v={push_enabled:patch.pushEnabled??current.pushEnabled,message_enabled:patch.messageEnabled??current.messageEnabled,group_enabled:patch.groupEnabled??current.groupEnabled,contact_request_enabled:patch.contactRequestEnabled??current.contactRequestEnabled,feel_it_enabled:patch.feelItEnabled??current.feelItEnabled,show_preview:patch.showPreview??current.showPreview};
  const r=await pool.query(`UPDATE notification_preferences SET push_enabled=$2,message_enabled=$3,group_enabled=$4,contact_request_enabled=$5,feel_it_enabled=$6,show_preview=$7,updated_at=now() WHERE user_id=$1 RETURNING *`,[userId,v.push_enabled,v.message_enabled,v.group_enabled,v.contact_request_enabled,v.feel_it_enabled,v.show_preview]); return mapPreferences(r.rows[0]);
}

export async function registerDevice(userId:string, deviceId:string|null, token:string, platform:string, appVersion?:string) {
  const encrypted=encryptPushToken(token); const hash=hashPushToken(token);
  const r=await pool.query(`INSERT INTO notification_devices(user_id,device_id,provider,token_hash,token_ciphertext,token_nonce,token_tag,platform,app_version,enabled,revoked_at,last_seen_at,updated_at) VALUES($1,$2,'fcm',$3,$4,$5,$6,$7,$8,TRUE,NULL,now(),now()) ON CONFLICT(provider,token_hash) DO UPDATE SET user_id=EXCLUDED.user_id,device_id=EXCLUDED.device_id,token_ciphertext=EXCLUDED.token_ciphertext,token_nonce=EXCLUDED.token_nonce,token_tag=EXCLUDED.token_tag,platform=EXCLUDED.platform,app_version=EXCLUDED.app_version,enabled=TRUE,revoked_at=NULL,last_seen_at=now(),updated_at=now() RETURNING id`,[userId,deviceId,hash,encrypted.ciphertext,encrypted.nonce,encrypted.tag,platform,appVersion??null]);
  return {deviceId:r.rows[0].id};
}

export async function unregisterDevice(userId:string, deviceId:string) {
  const r=await pool.query(`UPDATE notification_devices SET enabled=FALSE,revoked_at=now(),updated_at=now() WHERE id=$1 AND user_id=$2 RETURNING id`,[deviceId,userId]);
  if(!r.rows[0]) throw new Error('DEVICE_NOT_FOUND');
}

export async function queueNotification(userId:string,category:NotificationCategory,eventId?:string,conversationId?:string) {
  await pool.query(`INSERT INTO notification_outbox(user_id,category,event_id,conversation_id) VALUES($1,$2,$3,$4)`,[userId,category,eventId??null,conversationId??null]);
}

export async function processNotificationOutbox(limit=50) {
  const client=await pool.connect(); let count=0;
  try {
    for(;;){
      await client.query('BEGIN');
      const q=await client.query(`SELECT id,user_id,category,event_id,conversation_id FROM notification_outbox WHERE status='pending' AND available_at<=now() ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT $1`,[Math.max(1,Math.min(limit,100))]);
      if(!q.rows.length){await client.query('ROLLBACK');break;}
      const row=q.rows[0]; await client.query(`UPDATE notification_outbox SET status='processing',attempts=attempts+1 WHERE id=$1`,[row.id]); await client.query('COMMIT');
      await deliverQueued(row); count++;
    }
    return count;
  } finally {client.release();}
}

async function deliverQueued(row:any){
  const pref=await getPreferences(row.user_id); if(!pref.pushEnabled || !pref[prefKey(row.category)]) { await pool.query(`UPDATE notification_outbox SET status='sent',processed_at=now() WHERE id=$1`,[row.id]); return; }
  const devices=await pool.query(`SELECT id,token_ciphertext,token_nonce,token_tag FROM notification_devices WHERE user_id=$1 AND provider='fcm' AND enabled=TRUE AND revoked_at IS NULL`,[row.user_id]);
  const notification=buildPrivacySafeNotification(row.category,row.event_id??undefined);
  let delivered=0;
  for(const d of devices.rows){
    try { const token=decryptPushToken(d.token_ciphertext,d.token_nonce,d.token_tag); await sendFcm(token,{title:notification.title,body:notification.body,data:{category:notification.category,...(notification.eventId?{eventId:notification.eventId}:{})}}); await pool.query(`INSERT INTO notification_delivery_log(device_id,category,event_id,status) VALUES($1,$2,$3,'sent')`,[d.id,row.category,row.event_id]); delivered++; }
    catch(e){ const invalid=isInvalidFcmTokenError(e); await pool.query(`INSERT INTO notification_delivery_log(device_id,category,event_id,status,error_code) VALUES($1,$2,$3,$4,$5)`,[d.id,row.category,row.event_id,invalid?'revoked':'failed',invalid?'invalid-token':'provider-error']); if(invalid) await pool.query(`UPDATE notification_devices SET enabled=FALSE,revoked_at=now(),updated_at=now() WHERE id=$1`,[d.id]); }
  }
  await pool.query(`UPDATE notification_outbox SET status='sent',processed_at=now() WHERE id=$1`,[row.id]);
  void delivered;
}
function prefKey(category:NotificationCategory):'messageEnabled'|'groupEnabled'|'contactRequestEnabled'|'feelItEnabled' { return ({message:'messageEnabled',group:'groupEnabled',contact_request:'contactRequestEnabled',feel_it:'feelItEnabled'} as const)[category]; }
