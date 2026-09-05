-- File sharing milestone: reservations, finalization state, and secure metadata.
ALTER TABLE file_usage_daily
  ADD COLUMN IF NOT EXISTS reserved_bytes bigint NOT NULL DEFAULT 0 CHECK (reserved_bytes >= 0);

CREATE TABLE IF NOT EXISTS file_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  object_key text UNIQUE NOT NULL,
  original_name text NOT NULL,
  declared_size bigint NOT NULL CHECK (declared_size > 0),
  declared_mime text,
  status text NOT NULL CHECK (status IN ('pending','completed','aborted','expired')) DEFAULT 'pending',
  message_id uuid REFERENCES messages(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS file_uploads_user_status_idx ON file_uploads(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS file_uploads_expiry_idx ON file_uploads(status, expires_at);

ALTER TABLE attachments
  ADD COLUMN IF NOT EXISTS upload_id uuid UNIQUE REFERENCES file_uploads(id) ON DELETE SET NULL;
