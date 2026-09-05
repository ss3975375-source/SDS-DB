-- SDS-DB Milestone 05: group administration and invite links.
ALTER TABLE groups ADD CONSTRAINT groups_name_length CHECK (char_length(trim(name)) BETWEEN 1 AND 100);
ALTER TABLE conversation_members ADD CONSTRAINT conversation_member_role_valid CHECK (role IN ('member','moderator','admin'));

CREATE TABLE group_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES groups(conversation_id) ON DELETE CASCADE,
  token_hash text UNIQUE NOT NULL,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  max_uses integer NOT NULL DEFAULT 1 CHECK (max_uses BETWEEN 1 AND 1000),
  use_count integer NOT NULL DEFAULT 0 CHECK (use_count >= 0),
  revoked_at timestamptz,
  CHECK (expires_at > created_at),
  CHECK (use_count <= max_uses)
);
CREATE INDEX group_invites_conversation_idx ON group_invites(conversation_id, created_at DESC);
CREATE INDEX group_invites_active_idx ON group_invites(token_hash) WHERE revoked_at IS NULL;

CREATE INDEX conversation_members_user_active_idx
  ON conversation_members(user_id, conversation_id)
  WHERE left_at IS NULL;
