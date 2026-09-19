-- Follow-up to 077_rental_agreements_accepted_status.sql (separate file
-- for the same "can't use a freshly-added enum value in the same
-- transaction it was added in" reason). An accepted-but-unpaid row is
-- still a live pipeline on the asset -- it must keep blocking a second
-- requester from starting a competing rental_agreements row on the same
-- asset, same as documents_submitted/agreement_sent already do.
DROP INDEX IF EXISTS idx_rental_agreements_one_active_per_asset;

CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_agreements_one_active_per_asset
  ON rental_agreements (asset_id)
  WHERE status IN ('documents_submitted', 'agreement_sent', 'accepted');
