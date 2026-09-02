-- Referrals: agent-to-agent client referrals with fee sharing.
CREATE TABLE IF NOT EXISTS referrals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_name       TEXT NOT NULL,
  client_phone      TEXT NOT NULL,
  category_slug     TEXT NOT NULL,
  fee_percent       NUMERIC(5, 2) NOT NULL DEFAULT 10.0,
  status            TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, closed, declined
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_referrals_sender ON referrals (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_receiver ON referrals (receiver_id, created_at DESC);
