import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/server.js';

test('conversation list and direct-open endpoints are registered under the API prefix', async () => {
  const app = await buildApp();
  await app.ready();
  assert.equal(app.hasRoute({ method: 'GET', url: '/api/v1/conversations' }), true);
  assert.equal(app.hasRoute({ method: 'POST', url: '/api/v1/conversations/direct' }), true);
  await app.close();
});
