-- Closes the payment-method gap on the owner side: until now
-- rental_agreements.paid_at/payment_tx_ref could only be set by
-- rentalAgreements.markPaid(), which only ever fires off a Chapa
-- `/transaction/verify` success (see routes/payments.js). Renters who
-- pay the owner directly (bank transfer, cash) had no way to close the
-- loop -- there was no method column, no receipt column, and no route
-- to record it. This adds a parallel manual path: the owner marks the
-- agreement paid themselves and attaches proof.
--
-- payment_tx_ref stays NULL for manual payments -- it's specifically a
-- Chapa tx_ref (see payments.js), not a generic "payment reference"
-- column, so we don't overload it with a bank reference.

ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS payment_method   TEXT NOT NULL DEFAULT 'chapa'
    CHECK (payment_method IN ('chapa', 'manual_bank')),
  ADD COLUMN IF NOT EXISTS receipt_url      TEXT, -- data URI or hosted URL of the bank/cash receipt the owner uploaded
  ADD COLUMN IF NOT EXISTS marked_paid_by   UUID REFERENCES users(id); -- who confirmed it; NULL for the Chapa path (system-confirmed)
