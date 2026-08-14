-- Agent network: lets an agent recruit other agents to work under them
-- with their own referral link/code (separate from the Affiliater
-- program's affiliate_code/affiliate_referrals). Whenever a downline
-- agent earns a commission, their sponsor automatically earns an
-- override commission on top — see AGENT_NETWORK_OVERRIDE_PERCENT in
-- agentNetwork.js (6% for now).

-- Every agent gets one shareable code (e.g. "AGT-4F82K"), minted on
-- first request, same pattern as users.affiliate_code.
ALTER TABLE users ADD COLUMN IF NOT EXISTS agent_referral_code CITEXT UNIQUE;

-- The agent who recruited this agent, if any. Set once at signup (or via
-- POST /api/agents/:agentId/network/join) and never changed afterwards —
-- an agent has exactly one sponsor for the lifetime of the account.
ALTER TABLE users ADD COLUMN IF NOT EXISTS sponsor_agent_id UUID REFERENCES users (id);

CREATE INDEX IF NOT EXISTS idx_users_sponsor_agent_id ON users (sponsor_agent_id);

-- Marks which agent_wallet_transactions rows are override commissions
-- (as opposed to an agent's own direct-earned commissions), and which
-- downline agent's commission generated them. NULL for every ordinary
-- transaction (existing rows are unaffected).
ALTER TABLE agent_wallet_transactions ADD COLUMN IF NOT EXISTS source_agent_id UUID REFERENCES users (id);

CREATE INDEX IF NOT EXISTS idx_agent_wallet_tx_source_agent_id ON agent_wallet_transactions (source_agent_id);
