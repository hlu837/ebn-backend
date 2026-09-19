-- Lets a signed-in Visitor request to become an Affiliater, Agent/Broker,
-- or Investor without leaving the app. Submissions land in a queue for
-- Admin to approve/reject (same shape as sell_requests' submission
-- screening step); approval flips the user's `role` on the `users` table
-- so their next sign-in (or session refresh) routes them to the new
-- workspace via role_router.dart.

DO $$ BEGIN
  CREATE TYPE role_upgrade_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Only these three are requestable upgrades — Visitor is the default
-- starting role and Admin accounts are provisioned by the team, not
-- requested.
DO $$ BEGIN
  CREATE TYPE role_upgrade_target AS ENUM ('affiliater', 'agent', 'investor');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS role_upgrade_requests (
  id                                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id                              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_role                       role_upgrade_target NOT NULL,
  status                               role_upgrade_status NOT NULL DEFAULT 'pending',

  -- Visitor-supplied context for the request.
  message                              TEXT,
  agency_or_license                    TEXT,      -- Agent target only
  interested_in_fractional_investing   BOOLEAN NOT NULL DEFAULT false, -- Investor target only

  -- Admin decision.
  admin_note                           TEXT,
  decided_at                           TIMESTAMPTZ,

  created_at                           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_role_upgrade_requests_user ON role_upgrade_requests (user_id);
CREATE INDEX IF NOT EXISTS idx_role_upgrade_requests_status ON role_upgrade_requests (status);

-- Only one pending request per user at a time — resubmitting means
-- cancelling/waiting on the existing one first.
CREATE UNIQUE INDEX IF NOT EXISTS uq_role_upgrade_requests_one_pending_per_user
  ON role_upgrade_requests (user_id)
  WHERE status = 'pending';

DROP TRIGGER IF EXISTS trg_role_upgrade_requests_updated_at ON role_upgrade_requests;
CREATE TRIGGER trg_role_upgrade_requests_updated_at
  BEFORE UPDATE ON role_upgrade_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Extend the generic notification_kind enum (023_notifications.sql) with
-- the kinds this feature needs. Separate ALTER TYPE from any USE of the
-- new values in the same deploy, per the note in
-- 024_notification_kind_affiliate.sql.
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'role_upgrade';
