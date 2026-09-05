import test from 'node:test';
import assert from 'node:assert/strict';
import { toSessionView } from '../src/services/sessionSecurityService.js';

test('session view marks only the matching session current', () => {
  const view = toSessionView({
    id: '11111111-1111-1111-1111-111111111111',
    device_id: '22222222-2222-2222-2222-222222222222',
    device_name: 'Android phone',
    platform: 'android',
    created_at: '2026-09-04T10:00:00.000Z',
    last_seen_at: '2026-09-04T10:05:00.000Z',
    revoked_at: null,
  }, '11111111-1111-1111-1111-111111111111');
  assert.equal(view.current, true);
  assert.equal(view.deviceName, 'Android phone');
});

test('session view exposes no network or hardware identifiers', () => {
  const view = toSessionView({
    id: '11111111-1111-1111-1111-111111111111',
    created_at: '2026-09-04T10:00:00.000Z',
  }, 'other');
  assert.equal('ipAddress' in view, false);
  assert.equal('hardwareId' in view, false);
  assert.equal(view.current, false);
});
