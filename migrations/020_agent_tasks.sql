-- Backs the Agent dashboard's "Tasks" quick action with a real, persisted
-- to-do list, replacing what used to be a static PlaceholderPage. Optional
-- links to a tour/order request cover "Reminders tied to leads and tours";
-- `created_by` distinguishes tasks the agent made for themselves from ones
-- an Admin assigned to them ("Shared tasks from Admin").

CREATE TABLE IF NOT EXISTS agent_tasks (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  agent_id                  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title                     TEXT NOT NULL,
  done                      BOOLEAN NOT NULL DEFAULT false,
  due_at                    TIMESTAMPTZ,

  linked_tour_request_id    UUID REFERENCES tour_requests (id) ON DELETE SET NULL,
  linked_order_request_id   UUID REFERENCES order_requests (id) ON DELETE SET NULL,

  created_by                TEXT NOT NULL DEFAULT 'agent' CHECK (created_by IN ('agent', 'admin')),

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_agent_id ON agent_tasks (agent_id, done, created_at DESC);

DROP TRIGGER IF EXISTS trg_agent_tasks_updated_at ON agent_tasks;
CREATE TRIGGER trg_agent_tasks_updated_at
  BEFORE UPDATE ON agent_tasks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
