-- Seeds `assets` with the same 13 listings that used to be hard-coded in
-- the client's `mock_asset_data.dart`, so the app has real content to show
-- the moment `GET /api/assets` goes live instead of an empty feed.
-- Safe to re-run: guarded by NOT EXISTS on title+city.

INSERT INTO assets (
  title, price_amount, price_currency, category_slug, status,
  address_line, city, latitude, longitude, attributes, image_url,
  posted_label, broker_id, rating, review_count, roi_percent
)
SELECT * FROM (VALUES
  ('Modern family home', 45000::numeric, 'ETB', 'house', 'active'::asset_status,
   'Bole Atlas, near Atlas Hotel', 'Addis Ababa', 8.9962, 38.7894,
   '{"bedrooms":4,"bathrooms":3,"sqft":2766}'::jsonb,
   'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80',
   'New · 1 hour ago', 'b4', 4.9::numeric, 120, 12.0::numeric),

  ('Downtown corner apartment', 32000::numeric, 'ETB', 'apartments', 'under_inspection'::asset_status,
   'Kazanchis, near UNECA', 'Addis Ababa', 9.0157, 38.7621,
   '{"bedrooms":2,"bathrooms":2,"sqft":1180}'::jsonb,
   'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&q=80',
   'New · 2 hours ago', 'b3', 4.7::numeric, 86, 9.5::numeric),

  ('2022 Toyota Camry SE', 4200000::numeric, 'ETB', 'vehicles', 'active'::asset_status,
   'EBN Lot, CMC', 'Addis Ababa', 9.0339, 38.7942,
   '{"year":2022,"make":"Toyota","model":"Camry","mileage":18000}'::jsonb,
   'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800&q=80',
   NULL, 'b1', NULL, NULL, NULL),

  ('CAT 320 Excavator', 18500000::numeric, 'ETB', 'machinery', 'active'::asset_status,
   'Industrial Zone, Bole Lemi', 'Addis Ababa', 8.9526, 38.8286,
   '{"type":"Excavator","year":2019,"hours":3400}'::jsonb,
   'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&q=80',
   'New · 5 hours ago', 'b6', NULL, NULL, NULL),

  ('Riverside villa, Bahir Dar', 6800000::numeric, 'ETB', 'building', 'sold'::asset_status,
   'Tana Riverside Rd', 'Bahir Dar', 11.6014, 37.3908,
   '{"bedrooms":3,"bathrooms":2,"sqft":1980}'::jsonb,
   'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&q=80',
   NULL, 'b4', 4.8::numeric, 54, 10.8::numeric),

  ('Studio near Bole Road', 18000::numeric, 'ETB', 'apartments', 'active'::asset_status,
   'Bole Medhanialem', 'Addis Ababa', 8.9908, 38.7847,
   '{"bedrooms":1,"bathrooms":1,"sqft":620}'::jsonb,
   'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80',
   'New · 1 day ago', 'b3', NULL, NULL, NULL),

  ('Family compound, Hawassa Lakeside', 52000::numeric, 'ETB', 'land', 'active'::asset_status,
   'Lake Hawassa Rd', 'Hawassa', 7.0504, 38.4955,
   '{"bedrooms":5,"bathrooms":4,"sqft":3100}'::jsonb,
   'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800&q=80',
   'New · 3 hours ago', 'b5', NULL, NULL, NULL),

  ('Two-bedroom condo, Sarbet', 6200000::numeric, 'ETB', 'condominium', 'active'::asset_status,
   'Sarbet Condominiums, Block 4', 'Addis Ababa', 8.9776, 38.7590,
   '{"bedrooms":2,"bathrooms":1,"sqft":980}'::jsonb,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80',
   'New · 6 hours ago', 'b4', 4.6::numeric, 39, 8.2::numeric),

  ('Storage warehouse, Bole Lemi', 210000::numeric, 'ETB', 'warehouse', 'active'::asset_status,
   'Bole Lemi Industrial Park', 'Addis Ababa', 8.9490, 38.8251,
   '{"sqft":8500}'::jsonb,
   'https://images.unsplash.com/photo-1553413077-190dd305871c?w=800&q=80',
   NULL, 'b7', NULL, NULL, NULL),

  ('Reinforcement steel bars, bulk lot', 980000::numeric, 'ETB', 'construction-materials', 'active'::asset_status,
   'Akaki Steel Yard', 'Addis Ababa', 8.8801, 38.8018,
   '{"condition":"New","quantity":"12 tons"}'::jsonb,
   'https://images.unsplash.com/photo-1541976590-713941681591?w=800&q=80',
   'New · 4 hours ago', 'b8', NULL, NULL, NULL),

  ('Isuzu FRR flatbed truck', 3100000::numeric, 'ETB', 'vehicles', 'active'::asset_status,
   'CMC Road, near Century Mall', 'Addis Ababa', 9.0201, 38.8298,
   '{"year":2018,"make":"Isuzu","model":"FRR","mileage":62000}'::jsonb,
   'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800&q=80',
   'New · 8 hours ago', 'b2', NULL, NULL, NULL),

  ('Komatsu D65 Bulldozer', 15200000::numeric, 'ETB', 'machinery', 'active'::asset_status,
   'CMC Road, near Century Mall', 'Addis Ababa', 9.0205, 38.8301,
   '{"type":"Bulldozer","year":2017,"hours":5100}'::jsonb,
   'https://images.unsplash.com/photo-1590496793929-36417d3117de?w=800&q=80',
   'New · 9 hours ago', 'b2', NULL, NULL, NULL),

  ('Lakeview plot, Hawassa', 2600000::numeric, 'ETB', 'land', 'active'::asset_status,
   'Lake Hawassa Rd, near Amora Gedel', 'Hawassa', 7.0462, 38.4769,
   '{"sqft":5000}'::jsonb,
   'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800&q=80',
   'New · 12 hours ago', 'b9', NULL, NULL, NULL)
) AS seed(
  title, price_amount, price_currency, category_slug, status,
  address_line, city, latitude, longitude, attributes, image_url,
  posted_label, broker_id, rating, review_count, roi_percent
)
WHERE NOT EXISTS (
  SELECT 1 FROM assets a WHERE a.title = seed.title AND a.city = seed.city
);
