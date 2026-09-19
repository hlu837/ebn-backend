-- Lets a chat message carry a typed link to another record, so the client
-- can render an action button under the bubble instead of plain text only.
-- First use: rental-agreement messages ("Rental agreement sent…") get
-- kind = 'rental_agreement' and related_id = the agreement's id, which the
-- app turns into an "Open agreement" button for the tenant.
--
-- Both columns are nullable — every existing / ordinary message keeps
-- kind NULL and behaves exactly as before. Idempotent (migrate.js re-runs
-- every file each time).

ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS kind TEXT;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS related_id UUID;

-- Structured facts the client renders as a card (e.g. the rental agreement's
-- rent / advance / deposit / total / term). `body` always keeps a readable
-- plain-text version too, used for the inbox preview and older app builds.
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS meta JSONB;
