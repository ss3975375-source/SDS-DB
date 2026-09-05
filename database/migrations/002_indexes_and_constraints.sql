CREATE INDEX IF NOT EXISTS sessions_user_active_idx ON sessions(user_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS devices_user_last_seen_idx ON devices(user_id, last_seen_at DESC);
CREATE INDEX IF NOT EXISTS conversation_members_user_active_idx ON conversation_members(user_id, left_at);
CREATE INDEX IF NOT EXISTS attachments_owner_created_idx ON attachments(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS feel_it_posts_user_expiry_idx ON feel_it_posts(user_id, expires_at);
CREATE INDEX IF NOT EXISTS feel_it_viewers_viewed_idx ON feel_it_viewers(post_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS notifications_user_created_idx ON notifications(user_id, created_at DESC);

UPDATE users SET email = lower(email) WHERE email <> lower(email);
ALTER TABLE users ADD CONSTRAINT users_email_lower_chk CHECK (email = lower(email));
ALTER TABLE attachments ADD CONSTRAINT attachments_max_size_chk CHECK (byte_size <= 20 * 1024 * 1024 * 1024);
