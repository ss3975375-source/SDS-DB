import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/server.js';

test('health endpoint', async () => {
  const app = await buildApp();
  const response = await app.inject({ method: 'GET', url: '/health' });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: 'ok' });
  await app.close();
});
