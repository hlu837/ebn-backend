-- Activity log: a minimal audit trail. Scoped deliberately narrow for now
-- to the admin approve/reject decisions that matter most (sell-request
-- submissions/reports, investment commitments, role upgrade requests) —
-- not every mutation in the app. See routes using activityLogModel.create
-- for the exact write sites.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

CREATE TABLE IF NOT EXISTS activity_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  actor_id      TEXT NOT NULL,    -- the admin who performed the action
  actor_name    TEXT NOT NULL,

  action        TEXT NOT NULL,    -- e.g. 'sell_request.approve_submission'
  target_type   TEXT NOT NULL,    -- e.g. 'sell_request'
  target_id     TEXT NOT NULL,
  detail        TEXT,             -- free-text, e.g. a rejection reason

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON activity_log (created_at DESC);
