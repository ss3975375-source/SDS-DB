import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { getPreferences, registerDevice, unregisterDevice, updatePreferences, validatePushToken } from '../services/notificationService.js';

const prefSchema=z.object({pushEnabled:z.boolean().optional(),messageEnabled:z.boolean().optional(),groupEnabled:z.boolean().optional(),contactRequestEnabled:z.boolean().optional(),feelItEnabled:z.boolean().optional(),showPreview:z.boolean().optional()}).strict();
const deviceSchema=z.object({token:z.string().min(20).max(4096),platform:z.enum(['android','ios','web','desktop']),appVersion:z.string().trim().max(120).optional()});

export async function registerNotificationRoutes(app:FastifyInstance){
  app.get('/api/v1/notifications/preferences',{preHandler:requireAuth},async(req,reply)=>reply.send(await getPreferences(req.auth.userId)));
  app.put('/api/v1/notifications/preferences',{preHandler:requireAuth},async(req,reply)=>{const b=prefSchema.safeParse(req.body);if(!b.success)return reply.code(400).send({error:'invalid_preferences'});return reply.send(await updatePreferences(req.auth.userId,b.data));});
  app.post('/api/v1/notifications/devices',{preHandler:requireAuth},async(req,reply)=>{const b=deviceSchema.safeParse(req.body);if(!b.success||!validatePushToken(b.data.token))return reply.code(400).send({error:'invalid_push_token'});const s=await pool.query('SELECT device_id FROM sessions WHERE id=$1 AND user_id=$2 AND revoked_at IS NULL',[req.auth.sessionId,req.auth.userId]);const deviceId=s.rows[0]?.device_id??null;return reply.code(201).send(await registerDevice(req.auth.userId,deviceId,b.data.token,b.data.platform,b.data.appVersion));});
  app.delete('/api/v1/notifications/devices/:deviceId',{preHandler:requireAuth},async(req,reply)=>{const p=z.object({deviceId:z.string().uuid()}).safeParse(req.params);if(!p.success)return reply.code(400).send({error:'invalid_device_id'});try{await unregisterDevice(req.auth.userId,p.data.deviceId);return reply.code(204).send();}catch(e){if(e instanceof Error&&e.message==='DEVICE_NOT_FOUND')return reply.code(404).send({error:'device_not_found'});throw e;}});
}
