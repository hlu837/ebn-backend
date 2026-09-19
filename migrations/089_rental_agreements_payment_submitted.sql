-- Closes the tenant-can't-upload-their-own-receipt gap: until now the
-- only way a manual (bank transfer / cash) payment got recorded was
-- markPaidManually, which assumes the *owner* already has the receipt
-- in hand and uploads it themselves (see
-- 075_rental_agreements_manual_payment.sql). A tenant who pays by bank
-- transfer had no in-app way to hand over proof — they were told to
-- transfer, then message the owner in chat and hope it got sorted out.
--
-- This adds an explicit middle status: the tenant submits their own
-- receipt (rentalAgreements.submitReceipt) -> 'payment_submitted' ->
-- the owner reviews it and either confirms (rentalAgreements.
-- confirmReceipt -> 'paid', same close-out markPaid/markPaidManually
-- already do) or sends it back for a re-upload (rentalAgreements.
-- rejectReceipt -> back to 'accepted'). markPaidManually itself is
-- untouched — it's still the right call for a payment the owner
-- collected and can attest to directly (e.g. cash handed over in
-- person) without a tenant-submitted receipt in the loop at all.
--
-- Kept as its own migration for the usual reason: can't ALTER TYPE ...
-- ADD VALUE and reference the new value (e.g. in an index WHERE clause)
-- in the same transaction — see 077_rental_agreements_accepted_status.sql
-- / 078_rental_agreements_accepted_active_index.sql for the same split.
ALTER TYPE rental_agreement_status ADD VALUE IF NOT EXISTS 'payment_submitted';

-- When the tenant's own receipt was submitted — separate from
-- paid_at (set only once the owner actually confirms it) and from
-- receipt_url's existing meaning (the file itself, shared by both the
-- tenant-submitted and owner-submitted-on-tenant's-behalf paths).
ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS receipt_submitted_at TIMESTAMPTZ;

-- Free-text note the owner leaves when sending a submitted receipt back
-- for a re-upload (rejectReceipt) — e.g. "receipt shows a different
-- account name, please re-check and resend." Nullable, and overwritten
-- on every rejection — this is a "why was this bounced last time"
-- pointer for the tenant's screen, not an audit log.
ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS receipt_rejected_reason TEXT;
