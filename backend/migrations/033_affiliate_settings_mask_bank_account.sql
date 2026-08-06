-- Stop storing the affiliate's full bank account number. Only the last 4
-- digits are kept (matches the pattern already used by agent_settings /
-- bank_account_last4). The full number is only ever handled transiently in
-- the PATCH /api/affiliates/me/settings request body and is never written
-- to disk or logged — see affiliateSettings.js / routes/affiliates.js.

ALTER TABLE affiliate_settings
  ADD COLUMN IF NOT EXISTS bank_account_last4 TEXT;

-- Backfill from whatever was in the old column, then drop it. This is a
-- one-way migration: the full numbers that were previously stored in plain
-- text are intentionally not recoverable from bank_account_last4 alone.
UPDATE affiliate_settings
  SET bank_account_last4 = RIGHT(bank_account_number, 4)
  WHERE bank_account_number IS NOT NULL AND bank_account_last4 IS NULL;

ALTER TABLE affiliate_settings
  DROP COLUMN IF EXISTS bank_account_number;
