-- Session/device lifecycle hardening.
ALTER TABLE sessions
  ALTER COLUMN refresh_token_hash SET NOT NULL;

ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS app_version TEXT;

CREATE INDEX IF NOT EXISTS idx_sessions_user_created
  ON sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sessions_device_active
  ON sessions(device_id)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notification_devices_device
  ON notification_devices(device_id)
  WHERE enabled = TRUE AND revoked_at IS NULL;

-- A revoked device must not be resurrected by a stale refresh credential.
UPDATE sessions s
   SET revoked_at = COALESCE(s.revoked_at, now())
 WHERE s.revoked_at IS NULL
   AND EXISTS (SELECT 1 FROM devices d WHERE d.id = s.device_id AND d.revoked_at IS NOT NULL);
