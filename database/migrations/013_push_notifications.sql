-- Migration 013: push-notification hardening.
-- notification_devices and notification_preferences were introduced by
-- migration 007. Keep one canonical table definition and add only the
-- delivery-log table here.

CREATE TABLE IF NOT EXISTS notification_delivery_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID REFERENCES notification_devices(id) ON DELETE SET NULL,
  category TEXT NOT NULL CHECK (category IN ('message','group','contact_request','feel_it')),
  event_id UUID,
  status TEXT NOT NULL CHECK (status IN ('queued','sent','failed','expired','revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_device
  ON notification_delivery_log(device_id, created_at DESC);
