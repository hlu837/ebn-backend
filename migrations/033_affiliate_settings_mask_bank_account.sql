-- Stop storing the affiliate's full bank account number. Only the last 4
-- digits are kept (matches the pattern already used by agent_settings /
-- bank_account_last4). The full number is only ever handled transiently in
-- the PATCH /api/affiliates/me/settings request body and is never written
-- to disk or logged — see affiliateSettings.js / routes/affiliates.js.

ALTER TABLE affiliate_settings
  ADD COLUMN IF NOT EXISTS bank_account_last4 TEXT;

-- Backfill from whatever was in the old column (if it still exists), then
-- drop it. Guard with a DO block so this is safe to re-run on a fresh DB
-- where bank_account_number was never added or was already dropped.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'affiliate_settings' AND column_name = 'bank_account_number'
  ) THEN
    UPDATE affiliate_settings
      SET bank_account_last4 = RIGHT(bank_account_number, 4)
      WHERE bank_account_number IS NOT NULL AND bank_account_last4 IS NULL;
  END IF;
END $$;

ALTER TABLE affiliate_settings
  DROP COLUMN IF EXISTS bank_account_number;
