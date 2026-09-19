-- The Broker/Agent profile only ever stored a broad `city` (e.g. "Addis
-- Ababa"), but the public broker profile and map screens have always
-- displayed a more specific `addressLine` (e.g. "Jemo, Addis Ababa") —
-- that field just had nowhere to be set, so it was always null. This adds
-- the column the Flutter `Broker` model already expects.

ALTER TABLE agent_profiles
  ADD COLUMN IF NOT EXISTS address_line TEXT;
