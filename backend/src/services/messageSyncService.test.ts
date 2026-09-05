import test from 'node:test';
import assert from 'node:assert/strict';
import { decodeMessageCursor, encodeMessageCursor } from './messageSyncService.js';

test('message cursor round trips', () => {
  const cursor = {createdAt:'2026-09-04T10:00:00.000Z', id:'00000000-0000-4000-8000-000000000001'};
  assert.deepEqual(decodeMessageCursor(encodeMessageCursor(cursor)), cursor);
});

test('invalid cursor is rejected', () => {
  assert.equal(decodeMessageCursor('not-a-cursor'), null);
});
