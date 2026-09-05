-- Milestone 24: canonicalize legacy schemas and enforce database invariants.
-- This migration repairs earlier IF NOT EXISTS schema collisions so a clean
-- database and an upgraded database converge on the same canonical shape.

-- Feel It was originally declared in migration 001 with legacy column names;
-- migration 006 could not replace it because it used IF NOT EXISTS.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feel_it_posts' AND column_name='user_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feel_it_posts' AND column_name='author_id') THEN
    ALTER TABLE feel_it_posts RENAME COLUMN user_id TO author_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feel_it_posts' AND column_name='text_body')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feel_it_posts' AND column_name='text_content') THEN
    ALTER TABLE feel_it_posts RENAME COLUMN text_body TO text_content;
  END IF;
END $$;
ALTER TABLE feel_it_posts
  ADD COLUMN IF NOT EXISTS attachment_id uuid REFERENCES attachments(id) ON DELETE SET NULL;

ALTER TABLE feel_it_posts DROP CONSTRAINT IF EXISTS feel_it_has_content;
ALTER TABLE feel_it_posts DROP CONSTRAINT IF EXISTS feel_it_posts_check;
ALTER TABLE feel_it_posts DROP CONSTRAINT IF EXISTS feel_it_expiry_after_creation;
ALTER TABLE feel_it_posts ADD CONSTRAINT feel_it_has_content CHECK (
  text_content IS NOT NULL OR attachment_id IS NOT NULL OR object_key IS NOT NULL
);
ALTER TABLE feel_it_posts ADD CONSTRAINT feel_it_expiry_after_creation CHECK (expires_at > created_at);
CREATE INDEX IF NOT EXISTS idx_feel_it_active_author
  ON feel_it_posts(author_id, expires_at)
  WHERE deleted_at IS NULL;

-- Preserve legacy object keys during migration; new media uses attachments.
ALTER TABLE feel_it_posts
  ADD COLUMN IF NOT EXISTS legacy_object_key text;
UPDATE feel_it_posts
SET legacy_object_key = object_key
WHERE legacy_object_key IS NULL AND object_key IS NOT NULL;

-- Reports used target_user_id in migration 001 while later application code uses
-- reported_user_id. Rename the legacy column so all installations converge.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='reports' AND column_name='target_user_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='reports' AND column_name='reported_user_id') THEN
    ALTER TABLE reports RENAME COLUMN target_user_id TO reported_user_id;
  END IF;
END $$;

-- Normalize account deletion/reporting indexes after the canonical names exist.
CREATE INDEX IF NOT EXISTS idx_reports_reported_user
  ON reports(reported_user_id, created_at DESC)
  WHERE reported_user_id IS NOT NULL;

-- Stronger message lifecycle invariants.
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_body_or_attachment_chk;
ALTER TABLE messages ADD CONSTRAINT messages_expiry_valid_chk
  CHECK (expires_at IS NULL OR expires_at > created_at);

-- Refresh-token lookup remains indexed independently of mutable time predicates.
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_active
  ON sessions(refresh_token_hash)
  WHERE revoked_at IS NULL;

-- Ensure active notification devices have usable encrypted token material.
ALTER TABLE notification_devices
  ADD CONSTRAINT notification_device_token_hash_len_chk
  CHECK (char_length(token_hash) = 64);

-- Keep daily file-usage counters non-negative at the database boundary.
ALTER TABLE file_usage_daily DROP CONSTRAINT IF EXISTS file_usage_daily_reserved_check;
ALTER TABLE file_usage_daily ADD CONSTRAINT file_usage_daily_reserved_check
  CHECK (reserved_bytes >= 0 AND bytes_used >= 0);

-- Make the migration ledger available for operational tooling. The application
-- migration runner creates/populates this table before applying later changes.
CREATE TABLE IF NOT EXISTS schema_migrations (
  migration_key text PRIMARY KEY,
  checksum_sha256 text NOT NULL CHECK (char_length(checksum_sha256) = 64),
  applied_at timestamptz NOT NULL DEFAULT now()
);
