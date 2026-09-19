-- Seeds `affiliate_campaigns` with the same campaigns that used to be
-- hard-coded in the client's affiliate_campaigns_screen.dart, so the
-- Campaigns tab has real content the moment GET /api/affiliates/campaigns
-- goes live. Safe to re-run: guarded by NOT EXISTS on title.

INSERT INTO affiliate_campaigns (title, description, badge, icon, status, starts_at, ends_at)
SELECT * FROM (VALUES
  ('Summer Real Estate Drive',
   'Earn double commission (4%) on every house and apartment sale you refer through August.',
   '4% Commission', 'wb_sunny_outlined', 'active'::affiliate_campaign_status,
   now() - interval '10 days', now() + interval '20 days'),

  ('New Agent Referral Bonus',
   'Refer a new verified agent to the platform and earn a flat 5,000 ETB bonus once they close their first deal.',
   '5,000 ETB bonus', 'person_add_alt_1_outlined', 'active'::affiliate_campaign_status,
   now() - interval '30 days', NULL),

  ('Vehicle Marketplace Launch',
   'Special 3% commission tier on all vehicle listings, launching alongside the new vehicles category.',
   '3% Commission', 'directions_car_outlined', 'upcoming'::affiliate_campaign_status,
   now() + interval '15 days', NULL),

  ('New Year Kickoff',
   'Boosted commission tiers to open the year strong across all categories.',
   '3.5% Commission', 'celebration_outlined', 'ended'::affiliate_campaign_status,
   '2026-01-01'::timestamptz, '2026-01-31'::timestamptz)
) AS seed(title, description, badge, icon, status, starts_at, ends_at)
WHERE NOT EXISTS (
  SELECT 1 FROM affiliate_campaigns existing WHERE existing.title = seed.title
);
