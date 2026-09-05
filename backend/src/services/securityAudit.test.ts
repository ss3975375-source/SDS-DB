import test from 'node:test';
import assert from 'node:assert/strict';
import { redactSensitive, isProductionSafeCorsOrigin } from '../utils/security.js';

test('redacts nested authentication and secret fields', () => {
  assert.deepEqual(redactSensitive({ authorization: 'Bearer secret', nested: { refreshToken: 'abc', ok: 'value' } }), {
    authorization: '[REDACTED]', nested: { refreshToken: '[REDACTED]', ok: 'value' },
  });
});

test('production CORS requires HTTPS non-local origins', () => {
  assert.equal(isProductionSafeCorsOrigin('https://example.com'), true);
  assert.equal(isProductionSafeCorsOrigin('http://example.com'), false);
  assert.equal(isProductionSafeCorsOrigin('http://localhost:3000'), false);
});
