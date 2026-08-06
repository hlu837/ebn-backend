-- Investor network: lets an investor recruit other investors with their
-- own referral code + link (separate from the agent-to-agent network in
-- 040_agent_network.sql and the Affiliater program in 011_affiliates.sql).
-- Unlike agents, investors don't earn commissions to override — instead,
-- when a referred investor's *first* commitment is confirmed by an admin,
-- their sponsor is credited a one-time reward equal to a percentage of
-- that first commitment's amount. See INVESTOR_REFERRAL_REWARD_PERCENT
-- and creditReferralReward in investorNetwork.js.

-- Every investor gets one shareable code (e.g. "INV-4F82K"), minted on
-- first request, same pattern as users.affiliate_code / agent_referral_code.
ALTER TABLE users ADD COLUMN IF NOT EXISTS investor_referral_code CITEXT UNIQUE;

-- The investor who recruited this investor, if any. Set once at signup
-- (or via POST /api/investors/:investorId/network/join) and never changed
-- afterwards — an investor has exactly one sponsor for the life of the account.
ALTER TABLE users ADD COLUMN IF NOT EXISTS sponsor_investor_id UUID REFERENCES users (id);

CREATE INDEX IF NOT EXISTS idx_users_sponsor_investor_id ON users (sponsor_investor_id);

-- Marks which investor_wallet_transactions rows are referral rewards (as
-- opposed to an investor's own payout/withdrawal), and which downline
-- investor's first confirmed commitment generated them. NULL for every
-- ordinary transaction (existing rows are unaffected).
ALTER TABLE investor_wallet_transactions ADD COLUMN IF NOT EXISTS source_investor_id UUID REFERENCES users (id);

CREATE INDEX IF NOT EXISTS idx_investor_wallet_tx_source_investor_id ON investor_wallet_transactions (source_investor_id);
