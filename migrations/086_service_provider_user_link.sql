-- Links a service_providers row to a users row, so a specialist can log
-- in instead of being purely admin-managed (see 082_service_providers.sql's
-- note: "If a provider ever needs their own login ... add a nullable
-- user_id UUID REFERENCES users(id) column then rather than forcing every
-- provider through signup now" -- that time is now).
--
-- Product decision: there is no separate "Expert" account/role. An
-- existing Affiliater logs in as themselves and, if they have a linked
-- service_providers row (user_id = their user id), also gets access to
-- the Expert screens inside the same Affiliate dashboard (profile, jobs,
-- payout ledger) -- see affiliates.js's /me/expert-* routes. This column
-- is what makes that link.
--
-- Nullable: most providers still won't have a login (082's original
-- reasoning still holds for admin-entered specialists who never signed
-- up as an affiliate). Self-service profiles created via POST
-- /api/affiliates/me/expert-profile always set this column; admin-entered
-- ones leave it null unless an admin links them to an affiliate account.

ALTER TABLE service_providers ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- One expert profile per user account.
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_providers_user_id
  ON service_providers (user_id)
  WHERE user_id IS NOT NULL;
