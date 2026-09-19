-- Closes a real race in rentalAgreements.submitDocuments: two different
-- requesters could both send a rent_now request and both submit
-- documents before either one gets the asset flipped to 'reserved',
-- landing two competing "active" rental_agreements rows on the same
-- asset. The model-level SELECT-then-INSERT check added alongside this
-- migration narrows the window but can't close it by itself — this
-- partial unique index is the actual guarantee, enforced by Postgres
-- regardless of timing.
CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_agreements_one_active_per_asset
  ON rental_agreements (asset_id)
  WHERE status IN ('documents_submitted', 'agreement_sent');
