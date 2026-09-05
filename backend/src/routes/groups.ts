import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { addMembers, createGroup, createInvite, getGroup, joinByInvite, leaveGroup, listGroups, removeMember, revokeInvite, setMemberRole, updateGroupName } from '../services/group.service.js';

const uuid = z.string().uuid();
const groupIdParams = z.object({ conversationId: uuid });
const memberSchema = z.object({ userIds: z.array(uuid).min(1).max(100) });
const roleSchema = z.object({ role: z.enum(['member','moderator','admin']) });
const nameSchema = z.object({ name: z.string().trim().min(1).max(100) });
const inviteSchema = z.object({ ttlHours: z.number().int().min(1).max(168).default(24), maxUses: z.number().int().min(1).max(1000).default(1) });
const inviteIdParams = z.object({ inviteId: uuid });
const joinSchema = z.object({ token: z.string().min(20).max(200) });

function sendError(reply: any, error: unknown) {
  const code = error instanceof Error ? error.message : '';
  const map: Record<string, [number,string]> = {
    FORBIDDEN:[403,'Not authorized for this group'], ADMIN_REQUIRED:[403,'Administrator permission required'],
    NOT_FOUND:[404,'Group or member not found'], USER_NOT_FOUND:[404,'One or more users were not found'],
    INVALID_NAME:[400,'Invalid group name'], TOO_MANY_MEMBERS:[400,'Group member limit exceeded'],
    INVALID_MEMBERS:[400,'Invalid members'], SELF_REMOVE_FORBIDDEN:[400,'You cannot remove yourself here; use leave group'],
    SELF_DEMOTION_FORBIDDEN:[400,'You cannot remove your own administrator role'], LAST_ADMIN:[409,'Transfer administrator role before leaving'],
    INVALID_TTL:[400,'Invalid invite expiration'], INVALID_MAX_USES:[400,'Invalid invite use limit'],
    INVALID_INVITE:[400,'Invalid, expired, revoked, or exhausted invite'],
  };
  const [status,message] = map[code] ?? [500,'Group operation failed'];
  if (status === 500) reply.request.log.error({err:error}, 'group operation failed');
  return reply.code(status).send({error:message});
}

export const groupRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', { preHandler: requireAuth }, async (req, reply) => reply.send({groups: await listGroups(req.auth.userId)}));
  app.post('/', { preHandler: requireAuth }, async (req, reply) => {
    const p = z.object({name:nameSchema.shape.name, userIds:z.array(uuid).max(499).default([])}).safeParse(req.body);
    if (!p.success) return reply.code(400).send({error:'Invalid group creation request'});
    try { return reply.code(201).send(await createGroup(req.auth.userId,p.data.name,p.data.userIds)); } catch(e) { return sendError(reply,e); }
  });
  app.get('/:conversationId', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.safeParse(req.params); if(!p.success)return reply.code(400).send({error:'Invalid group id'});
    try{return reply.send(await getGroup(req.auth.userId,p.data.conversationId));}catch(e){return sendError(reply,e);}
  });
  app.patch('/:conversationId', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.safeParse(req.params); const b=nameSchema.safeParse(req.body);
    if(!p.success||!b.success)return reply.code(400).send({error:'Invalid group update'});
    try{return reply.send(await updateGroupName(req.auth.userId,p.data.conversationId,b.data.name));}catch(e){return sendError(reply,e);}
  });
  app.post('/:conversationId/members', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.safeParse(req.params); const b=memberSchema.safeParse(req.body);
    if(!p.success||!b.success)return reply.code(400).send({error:'Invalid member request'});
    try{return reply.send(await addMembers(req.auth.userId,p.data.conversationId,b.data.userIds));}catch(e){return sendError(reply,e);}
  });
  app.delete('/:conversationId/members/:userId', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.extend({userId:uuid}).safeParse(req.params); if(!p.success)return reply.code(400).send({error:'Invalid member'});
    try{await removeMember(req.auth.userId,p.data.conversationId,p.data.userId);return reply.code(204).send();}catch(e){return sendError(reply,e);}
  });
  app.patch('/:conversationId/members/:userId/role', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.extend({userId:uuid}).safeParse(req.params); const b=roleSchema.safeParse(req.body);
    if(!p.success||!b.success)return reply.code(400).send({error:'Invalid role request'});
    try{await setMemberRole(req.auth.userId,p.data.conversationId,p.data.userId,b.data.role);return reply.code(204).send();}catch(e){return sendError(reply,e);}
  });
  app.post('/:conversationId/leave', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.safeParse(req.params); if(!p.success)return reply.code(400).send({error:'Invalid group id'});
    try{await leaveGroup(req.auth.userId,p.data.conversationId);return reply.code(204).send();}catch(e){return sendError(reply,e);}
  });
  app.post('/:conversationId/invites', { preHandler: requireAuth }, async (req, reply) => {
    const p=groupIdParams.safeParse(req.params); const b=inviteSchema.safeParse(req.body ?? {});
    if(!p.success||!b.success)return reply.code(400).send({error:'Invalid invite request'});
    try{return reply.code(201).send(await createInvite(req.auth.userId,p.data.conversationId,b.data.ttlHours,b.data.maxUses));}catch(e){return sendError(reply,e);}
  });
  app.delete('/invites/:inviteId', { preHandler: requireAuth }, async (req, reply) => {
    const p=inviteIdParams.safeParse(req.params); if(!p.success)return reply.code(400).send({error:'Invalid invite id'});
    try{await revokeInvite(req.auth.userId,p.data.inviteId);return reply.code(204).send();}catch(e){return sendError(reply,e);}
  });
  app.post('/join', { preHandler: requireAuth }, async (req, reply) => {
    const b=joinSchema.safeParse(req.body); if(!b.success)return reply.code(400).send({error:'Invalid invite'});
    try{return reply.send(await joinByInvite(req.auth.userId,b.data.token));}catch(e){return sendError(reply,e);}
  });
};
