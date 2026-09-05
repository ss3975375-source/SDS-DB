-- Push notification device registrations and privacy preferences.
CREATE TABLE IF NOT EXISTS notification_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
  provider TEXT NOT NULL CHECK (provider IN ('fcm')),
  token_hash TEXT NOT NULL,
  token_ciphertext TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider, token_hash)
);

CREATE INDEX IF NOT EXISTS idx_notification_devices_user
  ON notification_devices(user_id)
  WHERE enabled = TRUE;

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  message_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  group_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  contact_request_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  feel_it_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  show_preview BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-conversation mute settings.
CREATE TABLE IF NOT EXISTS notification_mutes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  muted_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, conversation_id)
);
