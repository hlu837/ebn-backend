DO $$ BEGIN
  CREATE TYPE announcement_category AS ENUM ('General', 'Payout', 'Update');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  title       TEXT NOT NULL,
  content     TEXT NOT NULL,
  category    announcement_category NOT NULL DEFAULT 'General',
  is_pinned   BOOLEAN NOT NULL DEFAULT false,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_announcements_pinned_created ON announcements (is_pinned DESC, created_at DESC);
