-- Keep publication a recoverable two-phase operation across YouTube and PostgreSQL.
ALTER TABLE video_submissions DROP CONSTRAINT valid_status;
ALTER TABLE video_submissions ADD CONSTRAINT valid_status
 CHECK (status IN ('DRAFT','UPLOADING','PRIVATE_REVIEW','REJECTED',
                   'APPROVED','PUBLISHING','PUBLISHED','REMOVED'));
