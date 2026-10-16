-- Feel It: ephemeral status/story-style content.
-- Repair legacy columns created by migration 001 before defining canonical indexes.
DO LANGUAGE plpgsql '
BEGIN
  IF to_regclass(''public.feel_it_posts'') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=''public'' AND table_name=''feel_it_posts'' AND column_name=''user_id'')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=''public'' AND table_name=''feel_it_posts'' AND column_name=''author_id'') THEN
      ALTER TABLE feel_it_posts RENAME COLUMN user_id TO author_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=''public'' AND table_name=''feel_it_posts'' AND column_name=''text_body'')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=''public'' AND table_name=''feel_it_posts'' AND column_name=''text_content'') THEN
      ALTER TABLE feel_it_posts RENAME COLUMN text_body TO text_content;
    END IF;
  END IF;
END
';

CREATE TABLE IF NOT EXISTS feel_it_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  attachment_id UUID REFERENCES attachments(id) ON DELETE SET NULL,
  text_content TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ,
  CONSTRAINT feel_it_has_content CHECK (
    text_content IS NOT NULL OR attachment_id IS NOT NULL
  ),
  CONSTRAINT feel_it_expiry_after_creation CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS feel_it_visibility (
  post_id UUID NOT NULL REFERENCES feel_it_posts(id) ON DELETE CASCADE,
  visibility_mode TEXT NOT NULL CHECK (
    visibility_mode IN ('contacts', 'selected', 'exclude')
  ),
  PRIMARY KEY (post_id)
);

CREATE TABLE IF NOT EXISTS feel_it_visibility_users (
  post_id UUID NOT NULL REFERENCES feel_it_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS feel_it_viewers (
  post_id UUID NOT NULL REFERENCES feel_it_posts(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, viewer_id)
);

CREATE TABLE IF NOT EXISTS feel_it_reactions (
  post_id UUID NOT NULL REFERENCES feel_it_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id),
  CONSTRAINT feel_it_reaction_length CHECK (char_length(reaction) BETWEEN 1 AND 32)
);

CREATE TABLE IF NOT EXISTS feel_it_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES feel_it_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT feel_it_reply_body_length CHECK (char_length(body) BETWEEN 1 AND 4000)
);

CREATE INDEX IF NOT EXISTS idx_feel_it_active_author
  ON feel_it_posts(author_id, expires_at)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_feel_it_active_expiry
  ON feel_it_posts(expires_at)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_feel_it_replies_post
  ON feel_it_replies(post_id, created_at);
