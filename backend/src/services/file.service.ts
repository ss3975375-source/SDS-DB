import { randomUUID } from 'node:crypto';
import {
  CreateMultipartUploadCommand, UploadPartCommand, CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand, HeadObjectCommand, DeleteObjectCommand, GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { pool } from '../db/pool.js';
import { config } from '../config/env.js';
import { storageBucket, storageClient } from '../config/storage.js';
import { reserveUploadQuota, releaseUploadQuota } from './quota.service.js';

const SAFE_MIME = /^(image\/(jpeg|png|webp|gif)|video\/(mp4|webm|quicktime)|audio\/(mpeg|mp4|wav|ogg|webm)|application\/(pdf|zip|json)|text\/(plain|csv)|application\/octet-stream)$/i;
const EXPIRY_MS = 60 * 60_000;
export const PART_SIZE = 8 * 1024 * 1024;

function cleanName(name: string): string { return name.normalize('NFKC').replace(/[\\/\0\r\n]/g, '_').trim().slice(0,255) || 'file'; }
function maxParts(size: bigint): number { return Number((size + BigInt(PART_SIZE) - 1n) / BigInt(PART_SIZE)); }

export async function createUpload(userId: string, input: { conversationId:string; size:bigint; mime?:string; name:string }) {
  if (input.size <= 0n || input.size > config.fileMaxBytes) throw new Error('FILE_TOO_LARGE');
  if (input.mime && !SAFE_MIME.test(input.mime)) throw new Error('UNSUPPORTED_MIME');
  if (maxParts(input.size) > 10000) throw new Error('FILE_TOO_LARGE');
  const quota = await reserveUploadQuota(userId, input.conversationId, input.size);
  const id = randomUUID();
  const objectKey = `uploads/${userId}/${quota.usageDate}/${id}`;
  const expiresAt = new Date(Date.now() + EXPIRY_MS);
  let multipartUploadId: string | undefined;
  try {
    const created = await storageClient.send(new CreateMultipartUploadCommand({Bucket:storageBucket,Key:objectKey,ContentType:input.mime || 'application/octet-stream',Metadata:{'sds-upload-id':id}}));
    multipartUploadId = created.UploadId;
    if (!multipartUploadId) throw new Error('STORAGE_INIT_FAILED');
    await pool.query(`INSERT INTO file_uploads(id,user_id,conversation_id,object_key,original_name,declared_size,declared_mime,status,expires_at,usage_date,multipart_upload_id) VALUES($1,$2,$3,$4,$5,$6,$7,'pending',$8,$9,$10)`, [id,userId,input.conversationId,objectKey,cleanName(input.name),input.size.toString(),input.mime ?? null,expiresAt,quota.usageDate,multipartUploadId]);
    return {uploadId:id,expiresAt,partSize:PART_SIZE,maxParts:maxParts(input.size),totalBytes:input.size.toString()};
  } catch (error) {
    if (multipartUploadId) await storageClient.send(new AbortMultipartUploadCommand({Bucket:storageBucket,Key:objectKey,UploadId:multipartUploadId})).catch(()=>undefined);
    await releaseUploadQuota(userId,input.conversationId,quota.usageDate,input.size);
    throw error;
  }
}

async function loadPending(userId:string, uploadId:string) {
  const q = await pool.query(`SELECT * FROM file_uploads WHERE id=$1 AND user_id=$2 FOR UPDATE`,[uploadId,userId]);
  const row=q.rows[0]; if(!row) throw new Error('NOT_FOUND');
  if(row.status!=='pending') throw new Error('UPLOAD_NOT_PENDING');
  if(new Date(row.expires_at).getTime()<=Date.now()) throw new Error('UPLOAD_EXPIRED');
  if(!row.multipart_upload_id) throw new Error('UPLOAD_INVALID');
  return row;
}

export async function listUploadParts(userId:string, uploadId:string) {
  const q=await pool.query(`SELECT f.declared_size,f.status,f.expires_at,p.part_number,p.etag,p.byte_size FROM file_uploads f LEFT JOIN file_upload_parts p ON p.upload_id=f.id WHERE f.id=$1 AND f.user_id=$2 ORDER BY p.part_number`,[uploadId,userId]);
  if(!q.rows[0]) throw new Error('NOT_FOUND');
  const first=q.rows[0]; if(first.status!=='pending') throw new Error('UPLOAD_NOT_PENDING'); if(new Date(first.expires_at).getTime()<=Date.now()) throw new Error('UPLOAD_EXPIRED');
  return {totalBytes:String(first.declared_size),partSize:PART_SIZE,parts:q.rows.filter((r:any)=>r.part_number!==null).map((r:any)=>({partNumber:r.part_number,etag:r.etag,byteSize:r.byte_size}))};
}

export async function signUploadPart(userId:string, uploadId:string, partNumber:number) {
  if(!Number.isInteger(partNumber)||partNumber<1||partNumber>10000) throw new Error('INVALID_PART');
  const q=await pool.query(`SELECT declared_size,multipart_upload_id,object_key,status,expires_at FROM file_uploads WHERE id=$1 AND user_id=$2`,[uploadId,userId]);
  const row=q.rows[0]; if(!row) throw new Error('NOT_FOUND');
  if(row.status!=='pending') throw new Error('UPLOAD_NOT_PENDING');
  if(new Date(row.expires_at).getTime()<=Date.now()) throw new Error('UPLOAD_EXPIRED');
  const total=BigInt(row.declared_size); const count=maxParts(total); if(partNumber>count) throw new Error('INVALID_PART');
  const start=BigInt(partNumber-1)*BigInt(PART_SIZE); const expected=Number(((start+BigInt(PART_SIZE))<total?BigInt(PART_SIZE):total-start));
  const url=await getSignedUrl(storageClient,new UploadPartCommand({Bucket:storageBucket,Key:row.object_key,UploadId:row.multipart_upload_id,PartNumber:partNumber}),{expiresIn:600});
  return {url,partNumber,expectedBytes:expected,expiresInSeconds:600};
}

export async function recordUploadPart(userId:string, uploadId:string, partNumber:number, etag:string, byteSize:number) {
  if(!Number.isInteger(partNumber)||partNumber<1||partNumber>10000||!etag||etag.length>1024||!Number.isSafeInteger(byteSize)||byteSize<=0) throw new Error('INVALID_PART');
  const client=await pool.connect();
  try { await client.query('BEGIN'); const row=await loadPending(userId,uploadId); const total=BigInt(row.declared_size); const count=maxParts(total); if(partNumber>count) throw new Error('INVALID_PART');
    const start=BigInt(partNumber-1)*BigInt(PART_SIZE); const expected=Number(((start+BigInt(PART_SIZE))<total?BigInt(PART_SIZE):total-start)); if(byteSize!==expected) throw new Error('SIZE_MISMATCH');
    await client.query(`INSERT INTO file_upload_parts(upload_id,part_number,etag,byte_size) VALUES($1,$2,$3,$4) ON CONFLICT(upload_id,part_number) DO UPDATE SET etag=EXCLUDED.etag,byte_size=EXCLUDED.byte_size,updated_at=now()`,[uploadId,partNumber,etag,byteSize]);
    await client.query('COMMIT'); return {partNumber,byteSize};
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function completeUpload(userId:string, uploadId:string) {
  const client=await pool.connect();
  try { await client.query('BEGIN'); const row=await loadPending(userId,uploadId); const parts=await client.query(`SELECT part_number,etag,byte_size FROM file_upload_parts WHERE upload_id=$1 ORDER BY part_number`,[uploadId]); const expectedCount=maxParts(BigInt(row.declared_size));
    if(parts.rows.length!==expectedCount) throw new Error('MISSING_PARTS');
    for(let i=0;i<parts.rows.length;i++) if(parts.rows[i].part_number!==i+1) throw new Error('MISSING_PARTS');
    const sum=parts.rows.reduce((a:any,p:any)=>a+BigInt(p.byte_size),0n); if(sum!==BigInt(row.declared_size)) throw new Error('SIZE_MISMATCH');
    await storageClient.send(new CompleteMultipartUploadCommand({Bucket:storageBucket,Key:row.object_key,UploadId:row.multipart_upload_id,MultipartUpload:{Parts:parts.rows.map((p:any)=>({ETag:p.etag,PartNumber:p.part_number}))}}));
    const head=await storageClient.send(new HeadObjectCommand({Bucket:storageBucket,Key:row.object_key})); const actual=BigInt(head.ContentLength??-1); if(actual!==BigInt(row.declared_size)){await storageClient.send(new DeleteObjectCommand({Bucket:storageBucket,Key:row.object_key})).catch(()=>undefined);throw new Error('SIZE_MISMATCH');}
    const attachment=await client.query(`INSERT INTO attachments(owner_id,object_key,byte_size,detected_mime,original_name,upload_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id,object_key,byte_size,detected_mime,original_name,created_at`,[userId,row.object_key,row.declared_size,head.ContentType??row.declared_mime,row.original_name,row.id]);
    await client.query(`UPDATE file_usage_daily SET reserved_bytes=GREATEST(0,reserved_bytes-$1),bytes_used=bytes_used+$1 WHERE user_id=$2 AND usage_date=$3::date AND conversation_id=$4`,[row.declared_size,userId,row.usage_date,row.conversation_id]);
    await client.query(`UPDATE file_uploads SET status='completed',completed_at=now() WHERE id=$1`,[uploadId]); await client.query('COMMIT'); return attachment.rows[0];
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function abortUpload(userId:string,uploadId:string){
  const client=await pool.connect(); try{await client.query('BEGIN');const q=await client.query(`SELECT * FROM file_uploads WHERE id=$1 AND user_id=$2 FOR UPDATE`,[uploadId,userId]);const row=q.rows[0];if(!row)throw new Error('NOT_FOUND');if(row.status==='pending'){await client.query(`UPDATE file_usage_daily SET reserved_bytes=GREATEST(0,reserved_bytes-$1) WHERE user_id=$2 AND usage_date=$3::date AND conversation_id=$4`,[row.declared_size,userId,row.usage_date,row.conversation_id]);await client.query(`UPDATE file_uploads SET status='aborted' WHERE id=$1`,[uploadId]);}await client.query('COMMIT');if(row.multipart_upload_id)await storageClient.send(new AbortMultipartUploadCommand({Bucket:storageBucket,Key:row.object_key,UploadId:row.multipart_upload_id})).catch(()=>undefined);else await storageClient.send(new DeleteObjectCommand({Bucket:storageBucket,Key:row.object_key})).catch(()=>undefined);
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}}

export async function attachToMessage(userId:string, uploadId:string, messageId:string) {
  const client=await pool.connect();
  try { await client.query('BEGIN');
    const q=await client.query(`SELECT a.id,a.owner_id,f.conversation_id,f.status FROM attachments a JOIN file_uploads f ON f.id=a.upload_id WHERE f.id=$1 AND f.user_id=$2 AND a.owner_id=$2 FOR UPDATE`,[uploadId,userId]);
    const attachment=q.rows[0]; if(!attachment) throw new Error('NOT_FOUND'); if(attachment.status!=='completed') throw new Error('UPLOAD_NOT_COMPLETED');
    const m=await client.query(`SELECT id FROM messages WHERE id=$1 AND conversation_id=$2 AND sender_id=$3 AND deleted_at IS NULL`,[messageId,attachment.conversation_id,userId]);
    if(!m.rows[0]) throw new Error('MESSAGE_FORBIDDEN');
    await client.query(`UPDATE attachments SET message_id=$1 WHERE id=$2 AND message_id IS NULL`,[messageId,attachment.id]);
    await client.query('COMMIT'); return {attachmentId:attachment.id,messageId};
  } catch(e){await client.query('ROLLBACK');throw e;} finally{client.release();}
}

export async function getDownloadUrl(userId:string,attachmentId:string){const q=await pool.query(`SELECT a.id,a.object_key,a.original_name,a.byte_size,a.detected_mime FROM attachments a JOIN messages m ON m.id=a.message_id JOIN conversation_members cm ON cm.conversation_id=m.conversation_id AND cm.user_id=$1 AND cm.left_at IS NULL WHERE a.id=$2 AND a.deleted_at IS NULL`,[userId,attachmentId]);const row=q.rows[0];if(!row)throw new Error('NOT_FOUND');const url=await getSignedUrl(storageClient,new GetObjectCommand({Bucket:storageBucket,Key:row.object_key}),{expiresIn:300});return {url,expiresInSeconds:300,fileName:row.original_name,byteSize:String(row.byte_size),mime:row.detected_mime};}
