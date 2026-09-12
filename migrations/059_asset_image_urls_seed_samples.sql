-- Sample multi-photo galleries for a few existing seeded listings, so the
-- detail screen's horizontally-scrollable image carousel (see
-- asset_detail_screen.dart) has something real to show immediately after
-- migrating, instead of only ever exercising the single-image code path.
-- Safe to re-run: plain UPDATEs keyed on title.

UPDATE assets SET image_urls = '[
  "https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&q=80",
  "https://images.unsplash.com/photo-1621252179027-94459d278660?w=800&q=80",
  "https://images.unsplash.com/photo-1610478065638-2f0a8f2eb2f0?w=800&q=80",
  "https://images.unsplash.com/photo-1580901369630-8a200ecfd6d5?w=800&q=80"
]'::jsonb
WHERE title = 'CAT 320 Excavator';

UPDATE assets SET image_urls = '[
  "https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80",
  "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&q=80",
  "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80"
]'::jsonb
WHERE title = 'Modern family home';

UPDATE assets SET image_urls = '[
  "https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800&q=80",
  "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800&q=80"
]'::jsonb
WHERE title = '2022 Toyota Camry SE';
