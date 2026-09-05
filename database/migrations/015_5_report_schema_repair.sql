-- Compatibility repair inserted before milestone 016.
-- Migration 001 called this column target_user_id, while later migrations and
-- application code use reported_user_id. Repair clean installations before 016.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='reports' AND column_name='target_user_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='reports' AND column_name='reported_user_id'
  ) THEN
    ALTER TABLE reports RENAME COLUMN target_user_id TO reported_user_id;
  END IF;
END $$;
