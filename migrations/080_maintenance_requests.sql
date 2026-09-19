-- Phase 1 of the maintenance-request workflow (see project notes).
-- One row per tenant-submitted issue against a unit they're actively
-- renting. "Actively renting" is enforced at the application layer
-- (maintenanceRequests.create requires an active rental_agreements row
-- for this tenant+asset — status = 'paid' AND vacated_at IS NULL) rather
-- than as a DB constraint, since the lease relationship can legitimately
-- end (vacate) after a request is already filed and closed out.
--
-- Flow: submitted -> (owner decides) -> accepted | rejected.
-- 'accepted' means the owner is handling it themselves or assigning an
-- external specialist directly (Phase 1 doesn't yet track who). Once
-- rejected, the tenant is free to assign a specialist from the service
-- directory themselves (Phase 3/4) and the row moves to 'assigned' ->
-- 'in_progress' -> 'completed' -> 'verified' via a later migration once
-- that flow exists — the enum below only carries the values this phase
-- actually uses, to avoid ambiguity about states nothing sets yet.

DO $$ BEGIN
  CREATE TYPE maintenance_request_status AS ENUM (
    'submitted',
    'accepted',
    'rejected'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE maintenance_request_category AS ENUM (
    'electrical',
    'plumbing',
    'structural',
    'appliance',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS maintenance_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  rental_agreement_id UUID NOT NULL REFERENCES rental_agreements(id),
  asset_id        UUID NOT NULL REFERENCES assets(id),
  owner_id        UUID NOT NULL REFERENCES users(id),
  tenant_id       UUID NOT NULL REFERENCES users(id),

  category        maintenance_request_category NOT NULL,
  description     TEXT NOT NULL,
  photo_urls      JSONB NOT NULL DEFAULT '[]',

  status          maintenance_request_status NOT NULL DEFAULT 'submitted',
  decided_at      TIMESTAMPTZ,
  decision_note   TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_owner_id ON maintenance_requests (owner_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_tenant_id ON maintenance_requests (tenant_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_asset_id ON maintenance_requests (asset_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_status ON maintenance_requests (status);
