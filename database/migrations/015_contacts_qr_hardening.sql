-- Milestone 15: database-backed Contacts + QR hardening.
-- contacts is retained in its original normalized shape (user_id, contact_user_id, status).
CREATE INDEX IF NOT EXISTS idx_contact_qr_user_created
  ON contact_qr_tokens(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contacts_accepted_user
  ON contacts(user_id, created_at DESC)
  WHERE status='accepted';
CREATE INDEX IF NOT EXISTS idx_contact_requests_pending_pair
  ON contact_requests(requester_id, recipient_id)
  WHERE status='pending';

-- Ensure every privacy-enabled user has an explicit settings row.
INSERT INTO privacy_settings(user_id)
SELECT u.id FROM users u
WHERE u.deleted_at IS NULL
ON CONFLICT (user_id) DO NOTHING;
