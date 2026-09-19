-- The Review tab's full lifecycle, intentionally left unmodeled by
-- 065_property_requests.sql ("the advance-payment / documents /
-- agreement / payment lifecycle described for the Review tab ... is a
-- separate follow-up"). This is that follow-up.
--
-- One row per 'rent_now' property_request that has progressed into the
-- document-review pipeline. Not every rent_now request gets a row here —
-- only once the requester actually submits their ID + documents does a
-- row get created (see rentalAgreements.submitDocuments).
--
-- Flow: documents_submitted -> (owner decides) -> agreement_sent
-- (24h countdown, see `expires_at`) -> paid | expired, or straight to
-- rejected. Payment reuses the existing generic `payments` table/Chapa
-- flow (backend/src/routes/payments.js) via a `rental_agreement_<id>`
-- purpose tag rather than a separate payments table here — see
-- `payment_tx_ref`.
--
-- While a row here is anywhere between documents_submitted and paid, the
-- listing's `assets.status` is pushed to 'reserved' so it disappears from
-- other users' search (assets.list() only shows 'active' by default) —
-- and pulled back to 'active' if the owner rejects it or the 24h window
-- lapses unpaid. On payment success it moves to 'rented'.

DO $$ BEGIN
  ALTER TYPE asset_status ADD VALUE IF NOT EXISTS 'reserved';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE asset_status ADD VALUE IF NOT EXISTS 'rented';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE rental_agreement_status AS ENUM (
    'documents_submitted',
    'agreement_sent',
    'paid',
    'rejected',
    'expired'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS rental_agreements (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- One rental pipeline per rent_now request — a requester who gets
  -- rejected/expired starts a fresh property_request (and thus a fresh
  -- row here) rather than reusing this one.
  property_request_id  UUID NOT NULL UNIQUE REFERENCES property_requests(id),
  asset_id             UUID NOT NULL REFERENCES assets(id),
  owner_id             UUID NOT NULL REFERENCES users(id),
  requester_id         UUID NOT NULL REFERENCES users(id),

  status               rental_agreement_status NOT NULL DEFAULT 'documents_submitted',

  -- Submitted by the requester up front.
  id_document_url      TEXT NOT NULL,
  document_urls        JSONB NOT NULL DEFAULT '[]',
  requester_note       TEXT,

  -- Filled in by the owner when they approve and send the agreement.
  agreement_terms       TEXT,
  rent_amount           NUMERIC(14, 2),
  deposit_amount        NUMERIC(14, 2),
  currency               TEXT NOT NULL DEFAULT 'ETB',
  sent_at                TIMESTAMPTZ,
  expires_at             TIMESTAMPTZ,

  -- Filled in when the owner rejects instead.
  rejected_reason        TEXT,
  rejected_at            TIMESTAMPTZ,

  -- Payment (see backend/src/routes/payments.js — purpose `rental_agreement_<id>`).
  payment_tx_ref         TEXT,
  paid_at                TIMESTAMPTZ,

  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_agreements_owner_id ON rental_agreements (owner_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_requester_id ON rental_agreements (requester_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_asset_id ON rental_agreements (asset_id);
CREATE INDEX IF NOT EXISTS idx_rental_agreements_status ON rental_agreements (status);
