-- Migration 017: production push notification hardening.
ALTER TABLE notification_devices
  ADD COLUMN IF NOT EXISTS token_nonce TEXT,
  ADD COLUMN IF NOT EXISTS token_tag TEXT,
  ADD COLUMN IF NOT EXISTS app_version TEXT,
  ADD COLUMN IF NOT EXISTS platform TEXT,
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notification_devices_hash
  ON notification_devices(provider, token_hash);
CREATE INDEX IF NOT EXISTS idx_notification_devices_active_user
  ON notification_devices(user_id, updated_at DESC)
  WHERE enabled = TRUE AND revoked_at IS NULL;

ALTER TABLE notification_delivery_log
  ADD COLUMN IF NOT EXISTS error_code TEXT;

CREATE TABLE IF NOT EXISTS notification_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('message','group','contact_request','feel_it')),
  event_id UUID,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','sent','failed','expired')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notification_outbox_pending
  ON notification_outbox(status, available_at, created_at)
  WHERE status IN ('pending','processing');
