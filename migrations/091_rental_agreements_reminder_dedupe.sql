-- Support for a stateless "sweep" endpoint (routes/cron.js) that can
-- stand in for the in-memory setTimeout timers in scheduler.js when
-- this backend runs somewhere that doesn't keep a Node process alive
-- between requests (serverless platforms like Vercel). The in-memory
-- timers (armPaymentReminder, armLeaseReminders) are one-shot by
-- construction — they simply never fire twice. A sweep that re-checks
-- "is this row past its reminder point?" on every run has no such
-- guarantee, so it needs its own dedupe columns to stay a one-time
-- send no matter how often the sweep runs.
--
-- These are purely a "have we already sent this?" marker per
-- reminder — cleared only if that particular payment/lease cycle
-- restarts (a rejected receipt gets a fresh window and should be able
-- to earn a fresh halfway reminder; see rentalAgreements.rejectReceipt).
ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS payment_reminder_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS lease_ending_reminder_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS lease_ended_notice_sent_at TIMESTAMPTZ;
