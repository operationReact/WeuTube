CREATE TABLE youtube_oauth_attempts (
 id UUID PRIMARY KEY,
 state VARCHAR(128) NOT NULL UNIQUE,
 admin_sub VARCHAR(128) NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL,
 consumed_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_youtube_oauth_attempts_expiry ON youtube_oauth_attempts(expires_at);
