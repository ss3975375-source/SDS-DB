-- Milestone 16: complete privacy, account deletion and reports.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;

ALTER TABLE account_deletion_jobs
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS failure_code TEXT;

ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS details TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE reports DROP CONSTRAINT IF EXISTS report_has_target;
ALTER TABLE reports ADD CONSTRAINT report_has_target CHECK (
  reported_user_id IS NOT NULL OR message_id IS NOT NULL OR conversation_id IS NOT NULL OR attachment_id IS NOT NULL
);
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_status_check;
ALTER TABLE reports ADD CONSTRAINT reports_status_check CHECK (status IN ('open','reviewing','resolved','dismissed'));

CREATE TABLE IF NOT EXISTS account_deletion_objects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES account_deletion_jobs(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL,
  deleted_at TIMESTAMPTZ,
  UNIQUE(job_id, object_key)
);
CREATE INDEX IF NOT EXISTS idx_account_deletion_objects_pending ON account_deletion_objects(job_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reports_conversation ON reports(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_message ON reports(message_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_attachment ON reports(attachment_id, created_at DESC);
