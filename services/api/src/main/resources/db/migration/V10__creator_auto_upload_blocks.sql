-- A creator explicitly revoked by an administrator must never regain
-- shared-platform channel access through automatic onboarding.
CREATE TABLE creator_channel_auto_upload_blocks (
 creator_sub VARCHAR(128) NOT NULL,
 youtube_channel_id VARCHAR(128) NOT NULL REFERENCES youtube_channels(youtube_channel_id),
 blocked_by_sub VARCHAR(128) NOT NULL,
 blocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(creator_sub,youtube_channel_id)
);
