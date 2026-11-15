CREATE TABLE youtube_oauth_credentials (
 id UUID PRIMARY KEY,
 youtube_channel_id VARCHAR(128) NOT NULL UNIQUE,
 channel_display_name VARCHAR(200) NOT NULL,
 refresh_token_ciphertext TEXT NOT NULL,
 encryption_key_reference VARCHAR(300) NOT NULL,
 connected_by_sub VARCHAR(128) NOT NULL,
 connected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_youtube_oauth_credentials_admin ON youtube_oauth_credentials(connected_by_sub);
