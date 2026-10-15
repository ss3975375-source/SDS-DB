import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/server.js';

test('message sync route is mounted under the client API path', async () => {
  const app = await buildApp();
  await app.ready();
  assert.equal(app.hasRoute({ method: 'GET', url: '/api/v1/messages/:conversationId/sync' }), true);
  assert.equal(app.hasRoute({ method: 'GET', url: '/:conversationId/sync' }), false);
  await app.close();
});
