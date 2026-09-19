-- Closes the structured-ID gap in the Review tab pipeline: the requester
-- has always had to upload a digital ID *photo* (id_document_url, see
-- 068_rental_agreements.sql), but nothing captured the actual Fayda
-- Identification Number (FIN) as data the owner (or, later, an
-- automated eKYC check against NIDP) can actually verify -- a repo-wide
-- search for "fayda"/"national_id" before this migration turned up
-- nothing at all.
--
-- Nullable, not NOT NULL: existing rows were submitted before this
-- column existed and have no FIN to backfill. New submissions are
-- required to provide one at the application layer instead (see
-- rentalAgreements.submitDocuments) -- same "enforce in code, not a DB
-- constraint" approach the rest of this table already takes with
-- id_document_url's application-level check.

ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS fayda_id_number TEXT; -- 12-digit Fayda FIN, digits only (validated in submitDocuments)
