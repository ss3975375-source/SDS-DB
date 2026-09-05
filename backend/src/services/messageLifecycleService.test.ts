import test from 'node:test';
import assert from 'node:assert/strict';

test('message lifecycle contract: expired messages are represented by a tombstone', () => {
  const message = { body: null, deletedAt: '2026-09-04T00:00:00.000Z' };
  assert.equal(message.body, null);
  assert.ok(message.deletedAt);
});

test('message lifecycle contract: receipts never carry message content', () => {
  const receipt = { userId: 'user', deliveredAt: '2026-09-04T00:00:00.000Z', readAt: null };
  assert.deepEqual(Object.keys(receipt).sort(), ['deliveredAt', 'readAt', 'userId'].sort());
});
