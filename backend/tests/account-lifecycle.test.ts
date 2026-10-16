import test from 'node:test';
import assert from 'node:assert/strict';
import { DELETION_GRACE_MS, validatePrivacyPatch } from '../src/services/accountLifecycleService.js';
import { isAllowedDuringAccountDeletion } from '../src/services/account-access-policy.js';

test('privacy patch accepts only documented values', () => {
  assert.deepEqual(validatePrivacyPatch({presenceEnabled:true, feelItDefaultVisibility:'selected'}), {presenceEnabled:true, feelItDefaultVisibility:'selected'});
  assert.throws(() => validatePrivacyPatch({unknown:true}), /UNKNOWN_PRIVACY_SETTING/);
  assert.throws(() => validatePrivacyPatch({presenceEnabled:'yes'}), /INVALID_PRIVACY_SETTING/);
  assert.throws(() => validatePrivacyPatch({feelItDefaultVisibility:'public'}), /INVALID_PRIVACY_SETTING/);
});

test('deletion grace period is 24 hours', () => assert.equal(DELETION_GRACE_MS, 24 * 60 * 60 * 1000));

test('pending deletion only permits status checks and cancellation', () => {
  assert.equal(isAllowedDuringAccountDeletion('GET', '/api/v1/account/deletion'), true);
  assert.equal(isAllowedDuringAccountDeletion('DELETE', '/api/v1/account/deletion'), true);
  assert.equal(isAllowedDuringAccountDeletion('GET', '/api/v1/account/deletion?details=1'), true);
  assert.equal(isAllowedDuringAccountDeletion('POST', '/api/v1/account/deletion'), false);
  assert.equal(isAllowedDuringAccountDeletion('GET', '/api/v1/privacy'), false);
  assert.equal(isAllowedDuringAccountDeletion('POST', '/api/v1/messages'), false);
});
