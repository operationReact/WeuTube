-- Public, embeddable videos already on an authorized YouTube channel.
-- Do not insert videos into WeuTube's publishing/approval workflow.
CREATE TABLE youtube_public_channel_catalog (
  youtube_video_id VARCHAR(11) PRIMARY KEY,
  youtube_channel_id VARCHAR(128) NOT NULL,
  channel_title VARCHAR(200) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  thumbnail_url TEXT NOT NULL,
  published_at TIMESTAMPTZ NOT NULL,
  duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
  view_count BIGINT,
  like_count BIGINT,
  comment_count BIGINT,
  short_candidate BOOLEAN NOT NULL DEFAULT FALSE,
  discovered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_yt_catalog_recent
  ON youtube_public_channel_catalog(published_at DESC, youtube_video_id DESC);
CREATE INDEX idx_yt_catalog_channel
  ON youtube_public_channel_catalog(youtube_channel_id, last_seen_at);
CREATE INDEX idx_yt_catalog_short
  ON youtube_public_channel_catalog(short_candidate, published_at DESC);

-- Observable importer state, not unverifiable "worker progress".
CREATE TABLE youtube_channel_catalog_sync (
  youtube_channel_id VARCHAR(128) PRIMARY KEY,
  channel_title VARCHAR(200) NOT NULL,
  status VARCHAR(32) NOT NULL CHECK
    (status IN ('IMPORTING','READY','ERROR')),
  imported_count INTEGER NOT NULL DEFAULT 0,
  last_success_at TIMESTAMPTZ,
  last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  error_code VARCHAR(80)
);
