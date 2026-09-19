-- Phase 4/6 of the maintenance-request workflow (see 080_maintenance_requests.sql
-- for Phase 1). 080's enum comment said it deliberately only carried the
-- values Phase 1 used; this is that follow-up, now that assignment
-- (Phase 4) and completion (Phase 6) exist.
--
-- No separate 'in_progress' state: the provider side isn't built yet (see
-- 084_maintenance_assignments.sql), so there's no second actor to move a
-- request from "assigned" to "in progress" — the tenant's own single
-- confirm-and-release action is what closes it out, straight from
-- 'assigned' to 'completed'.
--
-- Can't ALTER TYPE ... ADD VALUE and use the new value in the same
-- transaction, so this stays its own migration — see
-- 024_notification_kind_affiliate.sql for the same note.

ALTER TYPE maintenance_request_status ADD VALUE IF NOT EXISTS 'assigned';
ALTER TYPE maintenance_request_status ADD VALUE IF NOT EXISTS 'completed';
