-- Admin user management: lets an admin suspend/reactivate an account and
-- powers the Admin > Users list (GET /api/users), which previously had
-- nothing to query against.

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;

-- Admin list/search is always ordered newest-first and can be searched —
-- keep created_at indexed for the ORDER BY, on top of the existing role index.
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at DESC);
