-- Durable audit for payout decisions. No automatic payout provider is configured.
CREATE TABLE payout_decision_events (
 id UUID PRIMARY KEY,
 payout_id UUID NOT NULL REFERENCES payout_requests(id),
 reviewer_sub VARCHAR(128) NOT NULL,
 decision VARCHAR(32) NOT NULL CHECK (decision IN ('APPROVED','REJECTED')),
 reason VARCHAR(1000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_payout_decision_events_payout
 ON payout_decision_events(payout_id,created_at DESC);
