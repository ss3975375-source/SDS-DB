CREATE INDEX IF NOT EXISTS idx_contacts_user_created ON contacts(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_contact_pair ON contacts(LEAST(user_id, contact_user_id), GREATEST(user_id, contact_user_id));
CREATE INDEX IF NOT EXISTS idx_users_active_lookup ON users(id) WHERE deleted_at IS NULL;

ALTER TABLE contact_requests
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_contact_requests_pair
  ON contact_requests(requester_id, recipient_id, created_at DESC);
