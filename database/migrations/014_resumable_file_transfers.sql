-- Step 14: resumable private S3 multipart uploads.
ALTER TABLE file_uploads
  ADD COLUMN IF NOT EXISTS usage_date date NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE file_uploads
  ADD COLUMN IF NOT EXISTS multipart_upload_id text;

CREATE UNIQUE INDEX IF NOT EXISTS file_uploads_multipart_upload_idx
  ON file_uploads(multipart_upload_id)
  WHERE multipart_upload_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS file_upload_parts (
  upload_id uuid NOT NULL REFERENCES file_uploads(id) ON DELETE CASCADE,
  part_number integer NOT NULL CHECK (part_number BETWEEN 1 AND 10000),
  etag text NOT NULL CHECK (length(etag) BETWEEN 1 AND 1024),
  byte_size bigint NOT NULL CHECK (byte_size > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (upload_id, part_number)
);

CREATE INDEX IF NOT EXISTS file_upload_parts_upload_idx
  ON file_upload_parts(upload_id, part_number);
