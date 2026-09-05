import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { queueNotification } from '../services/notificationService.js';

const conversationParams = z.object({ conversationId: z.string().uuid() });
const messageParams = z.object({ messageId: z.string().uuid() });
const sendSchema = z.object({ body: z.string().trim().min(1).max(10000), clientMessageId: z.string().uuid().optional(), expiresInSeconds: z.number().int().min(0).max(30 * 24 * 60 * 60).optional() });
const pageSchema = z.object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(100).default(50) });

async function member(userId:string, conversationId:string) {
  const r=await pool.query(`SELECT cm.role,c.kind FROM conversation_members cm JOIN conversations c ON c.id=cm.conversation_id WHERE cm.user_id=$1 AND cm.conversation_id=$2 AND cm.left_at IS NULL AND c.deleted_at IS NULL`,[userId,conversationId]);
  if(!r.rows[0]) throw new Error('FORBIDDEN');
  return r.rows[0] as {role:string,kind:string};
}

export const messageRoutes: FastifyPluginAsync = async (app) => {
  app.post('/:conversationId', {preHandler:requireAuth}, async(req,reply)=>{
    const p=conversationParams.safeParse(req.params); const b=sendSchema.safeParse(req.body);
    if(!p.success||!b.success)return reply.code(400).send({error:'Invalid message'});
    try {
      await member(req.auth.userId,p.data.conversationId);
      const expiresAt=b.data.expiresInSeconds ? new Date(Date.now()+b.data.expiresInSeconds*1000) : null;
      const client = await pool.connect();
      let r: any;
      let replay = false;
      try {
        await client.query('BEGIN');
        if (b.data.clientMessageId) {
          const existing = await client.query(
            `SELECT id,conversation_id,sender_id,body,created_at,expires_at FROM messages WHERE sender_id=$1 AND client_message_id=$2 FOR UPDATE`,
            [req.auth.userId,b.data.clientMessageId],
          );
          if (existing.rows[0]) {
            const row = existing.rows[0];
            if (row.conversation_id !== p.data.conversationId || row.body !== b.data.body || String(row.expires_at ?? '') !== String(expiresAt ?? '')) {
              await client.query('ROLLBACK');
              return reply.code(409).send({error:'client_message_id_reused'});
            }
            r = existing;
            replay = true;
          }
        }
        if (!r) {
          r = await client.query(
            `INSERT INTO messages(conversation_id,sender_id,body,expires_at,client_message_id) VALUES($1,$2,$3,$4,$5) RETURNING id,conversation_id,sender_id,body,created_at,expires_at,client_message_id`,
            [p.data.conversationId,req.auth.userId,b.data.body,expiresAt,b.data.clientMessageId ?? null],
          );
        }
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally { client.release(); }
      if (replay) return reply.code(200).send({...r.rows[0],replayed:true});
      const recipients=await pool.query(`SELECT user_id FROM conversation_members WHERE conversation_id=$1 AND user_id<>$2 AND left_at IS NULL`,[p.data.conversationId,req.auth.userId]);
      const category=(await pool.query(`SELECT kind FROM conversations WHERE id=$1`,[p.data.conversationId])).rows[0]?.kind==='group'?'group':'message';
      await Promise.all(recipients.rows.map((x:any)=>queueNotification(x.user_id,category,r.rows[0].id,p.data.conversationId)));
      return reply.code(201).send(r.rows[0]);
    } catch(e){if(e instanceof Error&&e.message==='FORBIDDEN')return reply.code(403).send({error:'Not a conversation member'});req.log.error({err:e},'message send failed');return reply.code(500).send({error:'Unable to send message'});}
  });
  app.get('/:conversationId', {preHandler:requireAuth}, async(req,reply)=>{
    const p=conversationParams.safeParse(req.params); const q=pageSchema.safeParse(req.query);
    if(!p.success||!q.success)return reply.code(400).send({error:'Invalid message query'});
    try{await member(req.auth.userId,p.data.conversationId);const args:any[]=[p.data.conversationId];let where='m.conversation_id=$1 AND m.deleted_at IS NULL AND (m.expires_at IS NULL OR m.expires_at>now())';if(q.data.before){args.push(q.data.before);where+=' AND m.created_at<$2';}args.push(q.data.limit);const r=await pool.query(`SELECT m.id,m.conversation_id,m.sender_id,m.body,m.created_at,m.edited_at,m.expires_at FROM messages m WHERE ${where} ORDER BY m.created_at DESC LIMIT $${args.length}`,args);return reply.send({messages:r.rows,nextBefore:r.rows.length===q.data.limit?r.rows[r.rows.length-1].created_at:null});}catch(e){return reply.code(403).send({error:'Not a conversation member'});}
  });
  app.delete('/:conversationId/:messageId',{preHandler:requireAuth},async(req,reply)=>{const p=conversationParams.merge(messageParams).safeParse(req.params);if(!p.success)return reply.code(400).send({error:'Invalid message'});try{await member(req.auth.userId,p.data.conversationId);const r=await pool.query(`UPDATE messages SET deleted_at=now(),body=NULL WHERE id=$1 AND conversation_id=$2 AND sender_id=$3 AND deleted_at IS NULL RETURNING id`,[p.data.messageId,p.data.conversationId,req.auth.userId]);if(!r.rows[0])return reply.code(404).send({error:'Message not found'});return reply.code(204).send();}catch(e){return reply.code(403).send({error:'Not authorized'});}}
  );
};
