-- Metadata only: original video bytes remain on the creator's device until
-- they reach YouTube. The API relays small bounded chunks, never storing videos.
-- youtube_session_uri is a bearer-like Google capability; NEVER return or log it.
CREATE TABLE youtube_resumable_uploads (
  id UUID PRIMARY KEY,
  draft_id UUID NOT NULL UNIQUE REFERENCES video_submissions(id),
  creator_sub VARCHAR(128) NOT NULL,
  channel_id VARCHAR(128) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_mime VARCHAR(100) NOT NULL,
  total_bytes BIGINT NOT NULL CHECK (total_bytes > 0 AND total_bytes <= 274877906944),
  acknowledged_bytes BIGINT NOT NULL DEFAULT 0 CHECK (acknowledged_bytes >= 0),
  youtube_session_uri TEXT,
  youtube_video_id VARCHAR(128),
  status VARCHAR(24) NOT NULL CHECK (
    status IN ('INITIATING','ACTIVE','SENDING','RECONCILE','COMPLETED','FAILED','CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (acknowledged_bytes <= total_bytes)
);
CREATE INDEX idx_youtube_resumable_creator
  ON youtube_resumable_uploads(creator_sub,updated_at DESC);
