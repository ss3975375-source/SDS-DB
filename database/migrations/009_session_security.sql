ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS replaced_by_session_id UUID REFERENCES sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_user_active
  ON sessions(user_id, last_seen_at DESC)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_refresh_hash
  ON sessions(refresh_token_hash)
  WHERE refresh_token_hash IS NOT NULL;

ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_devices_user_active
  ON devices(user_id, last_seen_at DESC)
  WHERE revoked_at IS NULL;
