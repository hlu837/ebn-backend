-- Removes the 13 initial demo seed listings from the database.

DELETE FROM assets WHERE title IN (
  'Modern family home',
  'Downtown corner apartment',
  '2022 Toyota Camry SE',
  'CAT 320 Excavator',
  'Riverside villa, Bahir Dar',
  'Studio near Bole Road',
  'Family compound, Hawassa Lakeside',
  'Two-bedroom condo, Sarbet',
  'Storage warehouse, Bole Lemi',
  'Reinforcement steel bars, bulk lot',
  'Isuzu FRR flatbed truck',
  'Komatsu D65 Bulldozer',
  'Lakeview plot, Hawassa'
);
