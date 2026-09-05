import test from 'node:test';
import assert from 'node:assert/strict';
import { buildPrivacySafeNotification, hashPushToken, validatePushToken } from './notificationService.js';

test('push token validation rejects empty/short tokens', () => {
  assert.equal(validatePushToken('short'), false);
  assert.equal(validatePushToken('x'.repeat(20)), true);
  assert.equal(validatePushToken('x'.repeat(4097)), false);
});

test('push token hashes are deterministic and non-reversible by representation', () => {
  const a=hashPushToken('token-example-1234567890');
  assert.equal(a,hashPushToken('token-example-1234567890'));
  assert.match(a,/^[a-f0-9]{64}$/);
  assert.notEqual(a,'token-example-1234567890');
});

test('notification payloads never contain content', () => {
  const n=buildPrivacySafeNotification('message','11111111-1111-1111-1111-111111111111');
  assert.deepEqual(n,{title:'New message',body:'You have a new message',category:'message',eventId:'11111111-1111-1111-1111-111111111111'});
  assert.equal(JSON.stringify(n).includes('message body'),false);
});
