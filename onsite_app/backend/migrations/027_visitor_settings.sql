-- Visitor settings: notification prefs + app language from the Visitor's
-- "Account & Settings" screen. One row per user, created lazily on first
-- read/write (see visitorSettings.js) so signup doesn't need to know about
-- this table. Mirrors 016_agent_settings.sql's shape for the Visitor role.

CREATE TABLE IF NOT EXISTS visitor_settings (
  user_id                   UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

  notify_request_updates    BOOLEAN NOT NULL DEFAULT true,  -- replies on sell/order requests
  notify_chat_messages      BOOLEAN NOT NULL DEFAULT true,  -- broker/agent chat messages
  notify_price_drops        BOOLEAN NOT NULL DEFAULT true,  -- favorited listing changes
  notify_promotions         BOOLEAN NOT NULL DEFAULT false, -- product updates & promos

  language                  TEXT NOT NULL DEFAULT 'english', -- 'english' | 'amharic'

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_visitor_settings_updated_at ON visitor_settings;
CREATE TRIGGER trg_visitor_settings_updated_at
  BEFORE UPDATE ON visitor_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
