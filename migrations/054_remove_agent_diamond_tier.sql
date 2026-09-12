-- Diamond is not an agent membership tier. Existing Diamond agents are
-- preserved by moving them to the highest supported tier, Gold.
ALTER TABLE agent_memberships
	ALTER COLUMN tier DROP DEFAULT;

ALTER TABLE agent_memberships
	ALTER COLUMN tier TYPE TEXT USING tier::text;

UPDATE agent_memberships
SET tier = 'gold'
WHERE tier = 'diamond';

DROP TYPE agent_tier;

CREATE TYPE agent_tier AS ENUM ('bronze', 'silver', 'gold');

ALTER TABLE agent_memberships
	ALTER COLUMN tier TYPE agent_tier USING tier::agent_tier,
	ALTER COLUMN tier SET DEFAULT 'bronze';

DELETE FROM membership_pricing
WHERE role = 'agent' AND tier = 'diamond';