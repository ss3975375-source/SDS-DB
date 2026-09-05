CREATE TABLE IF NOT EXISTS contact_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  CONSTRAINT contact_request_not_self CHECK (requester_id <> recipient_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_contact_request
  ON contact_requests(LEAST(requester_id, recipient_id), GREATEST(requester_id, recipient_id))
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_contact_requests_recipient
  ON contact_requests(recipient_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_contact_requests_requester
  ON contact_requests(requester_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS contacts (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, contact_user_id),
  CONSTRAINT contacts_not_self CHECK (user_id <> contact_user_id)
);

CREATE INDEX IF NOT EXISTS idx_contacts_reverse
  ON contacts(contact_user_id, user_id);

CREATE TABLE IF NOT EXISTS contact_qr_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  max_uses INTEGER NOT NULL DEFAULT 1 CHECK (max_uses BETWEEN 1 AND 100),
  uses INTEGER NOT NULL DEFAULT 0 CHECK (uses >= 0),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contact_qr_active
  ON contact_qr_tokens(expires_at)
  WHERE revoked_at IS NULL;
