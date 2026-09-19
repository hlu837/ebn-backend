-- Closes the "rented forever" gap: once a rental_agreements row hits
-- 'paid', assets.status flips to 'rented' (see markPaid/markPaidManually)
-- and nothing anywhere ever tracks when that lease ends or moves the
-- listing back to 'active'. There's no lease_start/lease_end concept at
-- all outside the unrelated agent/investor *membership* renewal_date
-- columns (roleUpgradeRequests.js) -- a totally different feature.
--
-- This adds the minimum needed to track a lease's lifecycle without
-- auto-reopening a unit the owner hasn't confirmed is actually vacated
-- (a lease ending on paper doesn't mean the tenant moved out -- silently
-- making a possibly-still-occupied unit bookable again would be worse
-- than the current "stays rented forever" gap). See
-- rentalAgreements.markVacated for the explicit, owner-driven reopen.
--
-- lease_term_months: set by the owner alongside the other terms in
-- sendAgreement -- NULL means month-to-month / no fixed term, in which
-- case lease_end_at is never computed and no reminders fire.
-- lease_end_at: computed once, at markPaid/markPaidManually time, as
-- paid_at + lease_term_months. Drives the two one-shot reminders (see
-- routes/rentalAgreements.js armLeaseReminders) -- it does not move
-- automatically if the tenant later renews informally; a real renewal
-- flow is a separate follow-up.
-- vacated_at: set only by the owner via markVacated -- the sole trigger
-- that reopens the listing after a lease ends.
ALTER TABLE rental_agreements
  ADD COLUMN IF NOT EXISTS lease_term_months INTEGER,
  ADD COLUMN IF NOT EXISTS lease_end_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS vacated_at         TIMESTAMPTZ;

-- Backs listLeaseTracking() (re-arms reminder timers on boot, same
-- pattern as idx_rental_agreements_status backs listActive()).
CREATE INDEX IF NOT EXISTS idx_rental_agreements_lease_end_at
  ON rental_agreements (lease_end_at)
  WHERE status = 'paid' AND vacated_at IS NULL AND lease_end_at IS NOT NULL;
