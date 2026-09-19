-- Adds a real admin-reply field to support_tickets. Until now the only
-- state a ticket could hold was open/resolved (019_support_tickets.sql)
-- — the admin support detail screen already had a "Reply" text box in
-- the UI, but it only showed a toast saying replies weren't wired up
-- yet. This is the backing column for that.
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS admin_response TEXT;
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS admin_response_at TIMESTAMPTZ;
