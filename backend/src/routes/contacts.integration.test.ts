import test from 'node:test';
import assert from 'node:assert/strict';
import { generateContactQrToken, qrExpirySeconds, qrMaxUses, normalizeUserId } from '../services/contactService.js';

test('contact security primitives', async (t) => {
  await t.test('creates a high-entropy opaque QR token and stores a hash', () => {
    const a=generateContactQrToken(), b=generateContactQrToken();
    assert.notEqual(a.token,b.token); assert.equal(a.hash.length,64); assert.notEqual(a.hash,a.token);
  });
  await t.test('bounds QR expiry and usage', () => {
    assert.equal(qrExpirySeconds(undefined),600); assert.equal(qrMaxUses(undefined),1);
    assert.throws(()=>qrExpirySeconds(30)); assert.throws(()=>qrExpirySeconds(90000)); assert.throws(()=>qrMaxUses(0)); assert.throws(()=>qrMaxUses(101));
  });
  await t.test('normalizes and bounds user ids', () => { assert.equal(normalizeUserId('  abc  '),'abc'); assert.throws(()=>normalizeUserId('')); });
});
