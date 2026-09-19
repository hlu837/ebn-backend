-- Agents need a location on file so order requests can be broadcast to
-- whoever's nearby. Nullable — an agent who hasn't set their location yet
-- simply won't show up in any nearby-agent search until they do.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS agent_latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS agent_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS agent_location_updated_at TIMESTAMPTZ;

-- Only ever queried for role = 'agent' rows, but a partial index keeps it
-- small and keeps the nearby-agent query fast as the table grows.
CREATE INDEX IF NOT EXISTS idx_users_agent_location
  ON users (agent_latitude, agent_longitude)
  WHERE role = 'agent' AND agent_latitude IS NOT NULL AND agent_longitude IS NOT NULL;
