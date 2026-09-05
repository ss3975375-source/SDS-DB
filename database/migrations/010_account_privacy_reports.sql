ALTER TABLE users
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS privacy_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  discoverable_by_user_id BOOLEAN NOT NULL DEFAULT TRUE,
  contact_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  read_receipts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  typing_indicators_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  presence_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  feel_it_default_visibility TEXT NOT NULL DEFAULT 'contacts'
    CHECK (feel_it_default_visibility IN ('contacts', 'selected', 'exclude')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS account_deletion_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  scheduled_for TIMESTAMPTZ NOT NULL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  failure_code TEXT
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_jobs_pending
  ON account_deletion_jobs(scheduled_for)
  WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  attachment_id UUID REFERENCES attachments(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT report_has_target CHECK (
    reported_user_id IS NOT NULL OR
    message_id IS NOT NULL OR
    conversation_id IS NOT NULL OR
    attachment_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter
  ON reports(reporter_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_status
  ON reports(status, created_at DESC);
