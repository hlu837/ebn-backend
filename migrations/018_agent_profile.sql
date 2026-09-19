-- Agent public profile: bio/city/specialties/boost from the
-- Visibility/Profile screen, plus the reviews shown there. This same data
-- (joined with `users`) is what the Broker Network directory lists other
-- agents from — one profile table serves both screens.

CREATE TABLE IF NOT EXISTS agent_profiles (
  user_id           UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

  bio               TEXT NOT NULL DEFAULT '',
  city              TEXT NOT NULL DEFAULT '',
  -- Asset category slugs, e.g. {apartments,house,land} — kept as text[]
  -- rather than a foreign table since the category list already lives as
  -- an enum-like set in the Flutter models, not in this DB.
  specialties       TEXT[] NOT NULL DEFAULT '{}',

  boosted           BOOLEAN NOT NULL DEFAULT false,
  boosted_until     TIMESTAMPTZ,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_agent_profiles_updated_at ON agent_profiles;
CREATE TRIGGER trg_agent_profiles_updated_at
  BEFORE UPDATE ON agent_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS agent_reviews (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  reviewer_name  TEXT NOT NULL,
  stars          SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
  quote          TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_reviews_agent_id ON agent_reviews (agent_id, created_at DESC);
