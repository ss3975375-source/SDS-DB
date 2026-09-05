-- Messaging reliability: client idempotency and deterministic sync cursors.
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS client_message_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS messages_sender_client_message_id_uq
  ON messages(sender_id, client_message_id)
  WHERE client_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS messages_sync_conversation_idx
  ON messages(conversation_id, created_at, id);

CREATE INDEX IF NOT EXISTS messages_sync_sender_idx
  ON messages(sender_id, created_at, id);
