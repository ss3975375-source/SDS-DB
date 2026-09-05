-- Message lifecycle hardening: durable delivery/read receipts and server-side expiry tombstones.
CREATE TABLE IF NOT EXISTS message_receipts (
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at timestamptz,
  read_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id),
  CHECK (read_at IS NULL OR delivered_at IS NOT NULL),
  CHECK (read_at IS NULL OR delivered_at <= read_at)
);
CREATE INDEX IF NOT EXISTS message_receipts_user_idx ON message_receipts(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS message_receipts_message_idx ON message_receipts(message_id, delivered_at, read_at);

-- The sender can query receipts efficiently, while membership authorization remains application-enforced.
CREATE INDEX IF NOT EXISTS messages_sender_created_idx ON messages(sender_id, created_at DESC, id);
