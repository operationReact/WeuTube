-- Only explicitly authorized creators may upload to a connected owner channel.
CREATE TABLE creator_channel_grants (
 creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
 youtube_channel_id VARCHAR(128) NOT NULL REFERENCES youtube_channels(youtube_channel_id),
 granted_by_sub VARCHAR(128) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(creator_id,youtube_channel_id)
);
CREATE INDEX idx_channel_grant_channel ON creator_channel_grants(youtube_channel_id);
