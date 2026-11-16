-- Real engagement is recorded only against published, owner-authorized submissions.
-- Demo items are virtual fixtures in the API and never enter these tables.
CREATE TABLE social_video_likes (
  video_id UUID NOT NULL REFERENCES video_submissions(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (video_id, creator_id)
);
CREATE TABLE social_video_saves (
  video_id UUID NOT NULL REFERENCES video_submissions(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (video_id, creator_id)
);
CREATE TABLE social_creator_follows (
  follower_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  followed_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followed_id),
  CONSTRAINT cannot_follow_self CHECK (follower_id <> followed_id)
);
CREATE TABLE social_video_comments (
  id UUID PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES video_submissions(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  content VARCHAR(400) NOT NULL CHECK (char_length(trim(content)) BETWEEN 1 AND 400),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_social_comments_video ON social_video_comments(video_id, created_at DESC);
CREATE INDEX idx_social_followed_creator ON social_creator_follows(followed_id);
