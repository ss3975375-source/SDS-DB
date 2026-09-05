import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { cancelAccountDeletion, createReport, getDeletionStatus, getPrivacySettings, requestAccountDeletion, updatePrivacySettings, validatePrivacyPatch } from '../services/accountLifecycleService.js';

export async function registerAccountRoutes(app: FastifyInstance) {
  app.get('/api/v1/privacy', {preHandler: requireAuth}, async (request, reply) => {
    try { return reply.send(await getPrivacySettings(request.auth.userId)); }
    catch (e) { request.log.error({err:e}, 'privacy read failed'); return reply.code(500).send({error:'Unable to read privacy settings'}); }
  });

  app.put('/api/v1/privacy', {preHandler: requireAuth}, async (request, reply) => {
    try {
      const patch = validatePrivacyPatch((request.body ?? {}) as Record<string, unknown>);
      return reply.send(await updatePrivacySettings(request.auth.userId, patch));
    } catch (e) {
      if (e instanceof Error && ['UNKNOWN_PRIVACY_SETTING','INVALID_PRIVACY_SETTING'].includes(e.message)) return reply.code(400).send({error:e.message.toLowerCase()});
      request.log.error({err:e}, 'privacy update failed'); return reply.code(500).send({error:'Unable to update privacy settings'});
    }
  });

  app.get('/api/v1/account/deletion', {preHandler: requireAuth}, async (request, reply) => reply.send(await getDeletionStatus(request.auth.userId)));

  app.post('/api/v1/account/deletion', {preHandler: requireAuth}, async (request, reply) => {
    const body = z.object({confirm:z.literal(true)}).safeParse(request.body);
    if (!body.success) return reply.code(400).send({error:'deletion_confirmation_required'});
    try { return reply.code(202).send(await requestAccountDeletion(request.auth.userId)); }
    catch (e) { if (e instanceof Error && e.message === 'ACCOUNT_ALREADY_DELETED') return reply.code(410).send({error:'account_deleted'}); request.log.error({err:e},'deletion request failed'); return reply.code(500).send({error:'Unable to request account deletion'}); }
  });

  app.delete('/api/v1/account/deletion', {preHandler: requireAuth}, async (request, reply) => {
    try { return reply.send(await cancelAccountDeletion(request.auth.userId)); }
    catch (e) { if (e instanceof Error && e.message === 'DELETION_NOT_CANCELLABLE') return reply.code(409).send({error:'deletion_not_cancellable'}); return reply.code(500).send({error:'Unable to cancel deletion'}); }
  });

  app.post('/api/v1/reports', {preHandler: requireAuth}, async (request, reply) => {
    const schema = z.object({reportedUserId:z.string().uuid().optional(),messageId:z.string().uuid().optional(),conversationId:z.string().uuid().optional(),attachmentId:z.string().uuid().optional(),reason:z.string().trim().min(1).max(200),details:z.string().max(4000).optional()});
    const body = schema.safeParse(request.body);
    if (!body.success) return reply.code(400).send({error:'invalid_report'});
    try { return reply.code(201).send(await createReport(request.auth.userId, body.data)); }
    catch (e) { if (e instanceof Error && ['INVALID_TARGET','REPORT_TARGET_UNAVAILABLE'].includes(e.message)) return reply.code(403).send({error:'report_target_unavailable'}); request.log.error({err:e},'report creation failed'); return reply.code(500).send({error:'Unable to create report'}); }
  });

}
