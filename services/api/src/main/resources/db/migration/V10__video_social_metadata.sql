-- Creator-supplied discovery metadata for legitimate, approved videos.
ALTER TABLE video_submissions
  ADD COLUMN category VARCHAR(50) NOT NULL DEFAULT 'Stories',
  ADD COLUMN description TEXT NOT NULL DEFAULT '';
CREATE INDEX idx_video_public_discovery
  ON video_submissions(status,updated_at DESC)
  WHERE status='PUBLISHED' AND youtube_video_id IS NOT NULL;
