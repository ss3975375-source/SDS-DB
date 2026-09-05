import test from 'node:test';
import assert from 'node:assert/strict';
import { isSafeNotificationBody, isValidFileSize, isValidPagination } from '../src/services/securityInvariants.js';

test('notification contract never accepts credential-like payloads', () => {
  assert.equal(isSafeNotificationBody('New message'), true);
  assert.equal(isSafeNotificationBody('refresh_token=secret'), false);
  assert.equal(isSafeNotificationBody('Authorization: Bearer abc'), false);
});

test('pagination contract bounds resource consumption', () => {
  assert.equal(isValidPagination(1, undefined), true);
  assert.equal(isValidPagination(100, 'cursor'), true);
  assert.equal(isValidPagination(101, undefined), false);
  assert.equal(isValidPagination(0, undefined), false);
});

test('file-size contract rejects unsafe values', () => {
  assert.equal(isValidFileSize(1, 10), true);
  assert.equal(isValidFileSize(0, 10), false);
  assert.equal(isValidFileSize(11, 10), false);
  assert.equal(isValidFileSize(Number.MAX_SAFE_INTEGER + 1, Number.MAX_SAFE_INTEGER + 2), false);
});
