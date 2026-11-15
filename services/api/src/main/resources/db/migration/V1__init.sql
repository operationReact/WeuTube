CREATE TABLE creators (
 id UUID PRIMARY KEY,
 cognito_sub VARCHAR(128) NOT NULL UNIQUE,
 display_name VARCHAR(150) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE youtube_channels (
 id UUID PRIMARY KEY,
 youtube_channel_id VARCHAR(128) NOT NULL UNIQUE,
 display_name VARCHAR(200) NOT NULL,
 monetized BOOLEAN NOT NULL DEFAULT FALSE,
 connected_at TIMESTAMPTZ
);
CREATE TABLE video_submissions (
 id UUID PRIMARY KEY,
 creator_id UUID NOT NULL REFERENCES creators(id),
 youtube_channel_id UUID REFERENCES youtube_channels(id),
 youtube_video_id VARCHAR(128) UNIQUE,
 title VARCHAR(200) NOT NULL,
 status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
 rejection_reason TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT valid_status CHECK (status IN ('DRAFT','UPLOADING','PRIVATE_REVIEW','REJECTED','APPROVED','PUBLISHED','REMOVED'))
);
CREATE TABLE revenue_ledger (
 id UUID PRIMARY KEY,
 creator_id UUID NOT NULL REFERENCES creators(id),
 video_id UUID REFERENCES video_submissions(id),
 amount_minor BIGINT NOT NULL,
 currency CHAR(3) NOT NULL DEFAULT 'INR',
 entry_type VARCHAR(30) NOT NULL,
 external_reference VARCHAR(200),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE payout_requests (
 id UUID PRIMARY KEY,
 creator_id UUID NOT NULL REFERENCES creators(id),
 amount_minor BIGINT NOT NULL CHECK(amount_minor > 0),
 currency CHAR(3) NOT NULL DEFAULT 'INR',
 status VARCHAR(32) NOT NULL DEFAULT 'REQUESTED',
 provider_reference VARCHAR(200),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_video_creator ON video_submissions(creator_id,created_at DESC);
CREATE INDEX idx_ledger_creator ON revenue_ledger(creator_id,created_at DESC);