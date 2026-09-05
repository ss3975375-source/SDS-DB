import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { acceptContactRequest, cancelContactRequest, consumeContactQr, createContactQr, declineContactRequest, discoverUser, listContactRequests, listContacts, normalizeUserId, removeContact, sendContactRequest } from '../services/contactService.js';

const uuid=z.string().uuid();
const idParams=z.object({requestId:uuid});
const userParams=z.object({userId:uuid});
function error(reply:any,e:unknown){const c=e instanceof Error?e.message:'';const map:any={SELF_CONTACT:[400,'You cannot add yourself'],BLOCKED:[403,'Contact operation unavailable'],REQUESTS_DISABLED:[403,'Contact requests are disabled'],ALREADY_CONTACT:[409,'Already a contact'],INCOMING_REQUEST_EXISTS:[409,'An incoming request already exists'],USER_NOT_FOUND:[404,'User not found'],REQUEST_NOT_FOUND:[404,'Request not found'],REQUEST_NOT_PENDING:[409,'Request is no longer pending'],FORBIDDEN:[403,'Not authorized'],INVALID_QR_TOKEN:[400,'Invalid or expired QR token'],NOT_FOUND:[404,'Contact not found']}; const [s,m]=map[c]??[500,'Contact operation failed']; if(s===500)reply.request.log.error({err:e},'contact operation failed'); return reply.code(s).send({error:m});}

export async function registerContactRoutes(app: FastifyInstance){
  app.get('/api/v1/contacts',{preHandler:requireAuth},async(req,reply)=>reply.send({contacts:await listContacts(req.auth.userId)}));
  app.get('/api/v1/contacts/requests',{preHandler:requireAuth},async(req,reply)=>reply.send({requests:await listContactRequests(req.auth.userId)}));
  app.post('/api/v1/contacts/requests',{preHandler:requireAuth},async(req,reply)=>{const b=z.object({userId:uuid}).safeParse(req.body);if(!b.success)return reply.code(400).send({error:'invalid_user_id'});try{return reply.code(201).send(await sendContactRequest(req.auth.userId,b.data.userId));}catch(e){return error(reply,e);}});
  app.post('/api/v1/contacts/requests/:requestId/accept',{preHandler:requireAuth},async(req,reply)=>{const p=idParams.safeParse(req.params);if(!p.success)return reply.code(400).send({error:'invalid_request_id'});try{return reply.send(await acceptContactRequest(req.auth.userId,p.data.requestId));}catch(e){return error(reply,e);}});
  app.post('/api/v1/contacts/requests/:requestId/decline',{preHandler:requireAuth},async(req,reply)=>{const p=idParams.safeParse(req.params);if(!p.success)return reply.code(400).send({error:'invalid_request_id'});try{return reply.send(await declineContactRequest(req.auth.userId,p.data.requestId));}catch(e){return error(reply,e);}});
  app.post('/api/v1/contacts/requests/:requestId/cancel',{preHandler:requireAuth},async(req,reply)=>{const p=idParams.safeParse(req.params);if(!p.success)return reply.code(400).send({error:'invalid_request_id'});try{return reply.send(await cancelContactRequest(req.auth.userId,p.data.requestId));}catch(e){return error(reply,e);}});
  app.delete('/api/v1/contacts/:userId',{preHandler:requireAuth},async(req,reply)=>{const p=userParams.safeParse(req.params);if(!p.success)return reply.code(400).send({error:'invalid_user_id'});try{await removeContact(req.auth.userId,p.data.userId);return reply.code(204).send();}catch(e){return error(reply,e);}});
  app.get('/api/v1/users/discover',{preHandler:requireAuth},async(req,reply)=>{const q=z.object({userId:uuid}).safeParse(req.query);if(!q.success)return reply.code(400).send({error:'invalid_query'});try{return reply.send(await discoverUser(req.auth.userId,q.data.userId));}catch(e){return error(reply,e);}});
  app.post('/api/v1/contacts/qr',{preHandler:requireAuth},async(req,reply)=>{const b=z.object({expiresInSeconds:z.number().int().min(60).max(86400).default(600),maxUses:z.number().int().min(1).max(100).default(1)}).safeParse(req.body??{});if(!b.success)return reply.code(400).send({error:'invalid_qr_options'});try{return reply.code(201).send(await createContactQr(req.auth.userId,b.data.expiresInSeconds,b.data.maxUses));}catch(e){return error(reply,e);}});
  app.post('/api/v1/contacts/qr/consume',{preHandler:requireAuth},async(req,reply)=>{const b=z.object({token:z.string().min(20).max(512)}).safeParse(req.body);if(!b.success)return reply.code(400).send({error:'invalid_qr_token'});try{return reply.send(await consumeContactQr(req.auth.userId,b.data.token));}catch(e){return error(reply,e);}});
}
