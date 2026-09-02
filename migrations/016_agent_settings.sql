-- Agent settings: notification prefs, app language, and payout/banking
-- details from the Settings screen. One row per agent, created lazily on
-- first read/write (see agentSettings.js) so signup doesn't need to know
-- about this table.

CREATE TABLE IF NOT EXISTS agent_settings (
  user_id                   UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

  notify_new_dispatches     BOOLEAN NOT NULL DEFAULT true,
  notify_chat_messages      BOOLEAN NOT NULL DEFAULT true,
  notify_promotions         BOOLEAN NOT NULL DEFAULT false,
  notify_payouts            BOOLEAN NOT NULL DEFAULT true,

  language                  TEXT NOT NULL DEFAULT 'english', -- 'english' | 'amharic'

  bank_name                 TEXT,
  bank_account_holder       TEXT,
  bank_account_last4        TEXT,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_agent_settings_updated_at ON agent_settings;
CREATE TRIGGER trg_agent_settings_updated_at
  BEFORE UPDATE ON agent_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
