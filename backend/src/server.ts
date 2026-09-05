import { registerContactRoutes } from './routes/contacts.js';
import { registerAccountRoutes } from './routes/account.js';
import { registerNotificationRoutes } from './routes/notifications.js';
import { registerFeelItRoutes } from './routes/feelIt.js';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { config } from './config/env.js';
import { authRoutes } from './routes/auth.js';
import { quotaRoutes } from './routes/quota.js';
import { fileRoutes } from './routes/files.js';
import { groupRoutes } from './routes/groups.js';
import { messageRoutes } from './routes/messages.js';
import { messageSyncRoutes } from './routes/messageSync.js';
import { pool } from './db/pool.js';
import { registerSessionRoutes } from './routes/sessions.js';
import { messageLifecycleRoutes } from './routes/messageLifecycle.js';
import { redactSensitive } from './utils/security.js';

export async function buildApp() {
  const app = Fastify({
    logger: {
      redact: [
        'req.headers.authorization', 'req.headers.cookie', 'request.headers.authorization',
        'req.body.identityToken', 'req.body.refreshToken', 'req.body.token', 'req.body.accessToken',
        'req.body.password', 'req.body.secret', 'req.body.privateKey',
        'res.headers.set-cookie',
      ],
    },
  });

  // Register cross-cutting security plugins before application routes so their
  // hooks apply consistently to every endpoint.
  await app.register(helmet, {
    global: true,
    contentSecurityPolicy: false,
    referrerPolicy: { policy: 'no-referrer' },
  });
  await app.register(cors, { origin: config.corsOrigin });
  await app.register(rateLimit, { max: 120, timeWindow: '1 minute', allowList: ['/health'] });

  app.get('/health', async () => ({ status: 'ok' }));

  await registerAccountRoutes(app);
  await registerContactRoutes(app);
  await registerNotificationRoutes(app);
  await registerFeelItRoutes(app);
  await registerSessionRoutes(app);
  app.register(authRoutes, { prefix: '/api/v1/auth' });
  app.register(quotaRoutes, { prefix: '/api/v1/files' });
  app.register(fileRoutes, { prefix: '/api/v1/files' });
  app.register(groupRoutes, { prefix: '/api/v1/groups' });
  app.register(messageSyncRoutes);
  app.register(messageRoutes, { prefix: '/api/v1/messages' });
  app.register(messageLifecycleRoutes, { prefix: '/api/v1/message-lifecycle' });
  app.setErrorHandler((error, request, reply) => {
    const message = error instanceof Error ? error.message : '';
    const authFailure = message === 'UNAUTHENTICATED' || error?.name === 'JWTExpired' || error?.name === 'JWSInvalid' || error?.name === 'JWTClaimValidationFailed';
    if (authFailure) {
      request.log.warn({ event: 'authn_failed', requestId: request.id }, 'authentication failed');
      return reply.code(401).send({ error: 'Authentication required' });
    }
    if (error && typeof error === 'object' && 'statusCode' in error && typeof (error as any).statusCode === 'number') {
      const status = (error as any).statusCode;
      if (status >= 400 && status < 500) return reply.code(status).send({ error: 'Request rejected' });
    }
    request.log.error({ err: redactSensitive(error), requestId: request.id }, 'request failed');
    if (!reply.sent) reply.code(500).send({ error: 'Internal server error' });
  });
  return app;
}

if (process.env.NODE_ENV !== 'test') {
  buildApp().then((app) => app.listen({ host: '0.0.0.0', port: config.port })).catch(async (error) => {
    console.error(error);
    await pool.end();
    process.exit(1);
  });
}
