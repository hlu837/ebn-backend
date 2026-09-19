-- Closes the missing-acceptance gap in the Review tab pipeline: until now
-- agreement_terms was a free-text field the owner types, and the status
-- machine went straight from agreement_sent -> paid with nothing in
-- between -- the API accepted a Chapa payment as the *only* signal that
-- the tenant ever agreed to the terms shown. There was no record of the
-- tenant having reviewed/accepted a specific version of the terms before
-- money moved.
--
-- This inserts an explicit 'accepted' state between agreement_sent and
-- paid: the requester must call POST /:id/accept (see
-- rentalAgreements.accept) before they can pay. accepted_at gives a
-- timestamped acceptance record independent of the payment itself.
--
-- Kept as its own migration, separate from any model/route code that
-- uses the new enum value -- can't ALTER TYPE ... ADD VALUE and use the
-- new value in the same transaction (see 069_notification_kind_rental_agreement.sql).
ALTER TYPE rental_agreement_status ADD VALUE IF NOT EXISTS 'accepted';

ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
