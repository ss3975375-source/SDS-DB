import test from 'node:test';
import assert from 'node:assert/strict';
import { generateContactQrToken, qrExpirySeconds, qrMaxUses } from '../src/services/contactService.js';

test('contact QR token is opaque and 32 random bytes encoded as base64url',()=>{const a=generateContactQrToken(),b=generateContactQrToken();assert.notEqual(a.token,b.token);assert.equal(a.hash.length,64);assert.match(a.token,/^[A-Za-z0-9_-]+$/);});
test('QR expiry is bounded',()=>{assert.equal(qrExpirySeconds(undefined),600);assert.equal(qrExpirySeconds(86400),86400);assert.throws(()=>qrExpirySeconds(59));assert.throws(()=>qrExpirySeconds(86401));});
test('QR uses are bounded',()=>{assert.equal(qrMaxUses(undefined),1);assert.equal(qrMaxUses(100),100);assert.throws(()=>qrMaxUses(0));assert.throws(()=>qrMaxUses(101));});
