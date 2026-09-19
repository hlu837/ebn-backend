-- Phases 4-6 of the maintenance-request workflow (see 080_maintenance_requests.sql
-- for Phase 1-2, 082_service_providers.sql for Phase 3).
--
-- One row per specialist a tenant assigns to a rejected request. Escrow
-- tracking is embedded directly on this row (payment_tx_ref/escrow_status/
-- held_at/released_at) rather than in a separate escrow_holds table --
-- same choice rental_agreements made for its own Chapa payment
-- (068_rental_agreements.sql: "reuses the existing generic payments table
-- ... via a purpose tag rather than a separate payments table"). The
-- generic `payments` table (004_payments.sql) still tracks the actual
-- Chapa checkout via purpose `maintenance_escrow_<assignment id>`; this
-- table's escrow_status is what the money is *for* (held against this
-- job vs released to the specialist vs refunded to the tenant), which
-- payments.status alone doesn't capture.
--
-- No provider login yet (082's note), so there's no "provider accepts /
-- provider marks done" step -- the tenant assigns, pays into escrow, and
-- later taps a single "confirm job done" action that both completes the
-- job and releases the funds in one step (see maintenanceAssignments.js
-- confirmComplete). completed_at doubles as that confirmation timestamp.

DO $$ BEGIN
  CREATE TYPE maintenance_assignment_escrow_status AS ENUM (
    'pending_payment', -- assigned, tenant hasn't paid into escrow yet
    'held',             -- Chapa payment succeeded, funds held
    'released',         -- tenant confirmed the job done; specialist_wallet credited
    'refunded'          -- admin refunded the tenant instead (dispute path)
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS maintenance_assignments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- One active assignment per request -- a tenant who wants to switch
  -- specialists would need the request reopened by an admin, not modeled
  -- here yet.
  maintenance_request_id UUID NOT NULL UNIQUE REFERENCES maintenance_requests(id),
  service_provider_id    UUID NOT NULL REFERENCES service_providers(id),
  tenant_id              UUID NOT NULL REFERENCES users(id),

  quoted_cost_cents      INTEGER NOT NULL CHECK (quoted_cost_cents > 0),
  currency               TEXT NOT NULL DEFAULT 'ETB',

  escrow_status           maintenance_assignment_escrow_status NOT NULL DEFAULT 'pending_payment',
  payment_tx_ref           TEXT, -- Chapa tx_ref, set once checkout is initialized (see payments.js)
  held_at                  TIMESTAMPTZ,
  released_at              TIMESTAMPTZ,
  refunded_at              TIMESTAMPTZ,
  refund_note              TEXT,

  -- Tenant's single confirm-and-release action.
  completed_at             TIMESTAMPTZ,

  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_assignments_tenant_id ON maintenance_assignments (tenant_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_assignments_provider_id ON maintenance_assignments (service_provider_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_assignments_escrow_status ON maintenance_assignments (escrow_status);

DROP TRIGGER IF EXISTS trg_maintenance_assignments_updated_at ON maintenance_assignments;
CREATE TRIGGER trg_maintenance_assignments_updated_at
  BEFORE UPDATE ON maintenance_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
