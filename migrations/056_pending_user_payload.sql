-- Stores unverified registration metadata on payments so user accounts are only created in the DB upon successful payment.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS pending_user_payload JSONB;
