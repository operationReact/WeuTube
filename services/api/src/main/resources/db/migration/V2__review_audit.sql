CREATE TABLE video_review_events (
 id UUID PRIMARY KEY,
 video_id UUID NOT NULL REFERENCES video_submissions(id),
 reviewer_sub VARCHAR(128) NOT NULL,
 decision VARCHAR(32) NOT NULL CHECK (decision IN ('APPROVED','REJECTED')),
 reason TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_video_review_events_video ON video_review_events(video_id,created_at DESC);
