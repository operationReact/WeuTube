-- A request key is unique per creator to avoid duplicate withdrawal requests.
ALTER TABLE payout_requests ADD COLUMN request_key UUID;
CREATE UNIQUE INDEX idx_payout_creator_request_key
 ON payout_requests(creator_id,request_key) WHERE request_key IS NOT NULL;
CREATE INDEX idx_payout_creator_status ON payout_requests(creator_id,status);
