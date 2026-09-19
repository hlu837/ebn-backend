-- Follow-up to 089_rental_agreements_payment_submitted.sql (separate
-- file for the same "can't use a freshly-added enum value in the same
-- transaction it was added in" reason — see
-- 078_rental_agreements_accepted_active_index.sql for the precedent).
--
-- A row sitting in 'payment_submitted' (tenant uploaded a receipt,
-- owner hasn't confirmed it yet) is still a live pipeline on the asset,
-- exactly like 'documents_submitted' / 'agreement_sent' / 'accepted'
-- already are — it must keep blocking a second requester from starting
-- a competing rental_agreements row on the same listing while the
-- owner is reviewing that receipt.
DROP INDEX IF EXISTS idx_rental_agreements_one_active_per_asset;

CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_agreements_one_active_per_asset
  ON rental_agreements (asset_id)
  WHERE status IN ('documents_submitted', 'agreement_sent', 'accepted', 'payment_submitted');
