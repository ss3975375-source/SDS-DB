import test from 'node:test';
import assert from 'node:assert/strict';
import { isSafeNotificationBody, isValidFileSize, isValidPagination } from './securityInvariants.js';

test('security invariants', async (t) => {
  await t.test('rejects credential-bearing notification text', () => {
    assert.equal(isSafeNotificationBody('New message'), true);
    assert.equal(isSafeNotificationBody('access_token=secret'), false);
  });
  await t.test('bounds pagination', () => {
    assert.equal(isValidPagination(50, undefined), true);
    assert.equal(isValidPagination(0, undefined), false);
    assert.equal(isValidPagination(101, undefined), false);
  });
  await t.test('bounds file size', () => {
    assert.equal(isValidFileSize(100, 1000), true);
    assert.equal(isValidFileSize(0, 1000), false);
    assert.equal(isValidFileSize(1001, 1000), false);
  });
});
