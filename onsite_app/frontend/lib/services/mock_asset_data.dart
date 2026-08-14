import '../models/asset.dart';

/// Hard-coded stand-in for the company's live listings — Addis Ababa and
/// a few other major Ethiopian cities, priced in ETB.
///
/// TODO: replace with a real `AssetService.fetchCompanyAssets()` call once
/// `GET /api/assets` exists on the backend (see README "next steps" — the
/// `assets` table and its JSONB `attributes` column are already migrated).
List<Asset> kMockCompanyAssets = [
  const Asset(
    id: '1',
    title: 'Modern family home',
    priceAmount: 45000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.house,
    status: AssetStatus.active,
    addressLine: 'Bole Atlas, near Atlas Hotel',
    city: 'Addis Ababa',
    attributes: {'bedrooms': 4, 'bathrooms': 3, 'sqft': 2766},
    imageUrl:
        'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80',
    postedLabel: 'New · 1 hour ago',
    brokerId: 'b4',
    rating: 4.9,
    reviewCount: 120,
    roiPercent: 12.0,
  ),
  const Asset(
    id: '2',
    title: 'Downtown corner apartment',
    priceAmount: 32000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.apartments,
    status: AssetStatus.underInspection,
    addressLine: 'Kazanchis, near UNECA',
    city: 'Addis Ababa',
    attributes: {'bedrooms': 2, 'bathrooms': 2, 'sqft': 1180},
    imageUrl:
        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&q=80',
    postedLabel: 'New · 2 hours ago',
    brokerId: 'b3',
    rating: 4.7,
    reviewCount: 86,
    roiPercent: 9.5,
  ),
  const Asset(
    id: '3',
    title: '2022 Toyota Camry SE',
    priceAmount: 4200000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.vehicles,
    status: AssetStatus.active,
    addressLine: 'EBN Lot, CMC',
    city: 'Addis Ababa',
    attributes: {
      'year': 2022,
      'make': 'Toyota',
      'model': 'Camry',
      'mileage': 18000
    },
    imageUrl:
        'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800&q=80',
    brokerId: 'b1',
  ),
  const Asset(
    id: '4',
    title: 'CAT 320 Excavator',
    priceAmount: 18500000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.machinery,
    status: AssetStatus.active,
    addressLine: 'Industrial Zone, Bole Lemi',
    city: 'Addis Ababa',
    attributes: {'type': 'Excavator', 'year': 2019, 'hours': 3400},
    imageUrl:
        'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&q=80',
    postedLabel: 'New · 5 hours ago',
    brokerId: 'b6',
  ),
  const Asset(
    id: '5',
    title: 'Riverside villa, Bahir Dar',
    priceAmount: 6800000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.building,
    status: AssetStatus.sold,
    addressLine: 'Tana Riverside Rd',
    city: 'Bahir Dar',
    attributes: {'bedrooms': 3, 'bathrooms': 2, 'sqft': 1980},
    imageUrl:
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&q=80',
    brokerId: 'b4',
    rating: 4.8,
    reviewCount: 54,
    roiPercent: 10.8,
  ),
  const Asset(
    id: '6',
    title: 'Studio near Bole Road',
    priceAmount: 18000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.apartments,
    status: AssetStatus.active,
    addressLine: 'Bole Medhanialem',
    city: 'Addis Ababa',
    attributes: {'bedrooms': 1, 'bathrooms': 1, 'sqft': 620},
    imageUrl:
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80',
    postedLabel: 'New · 1 day ago',
    brokerId: 'b3',
  ),
  const Asset(
    id: '7',
    title: 'Warehouse Complex, Addis Ababa',
    priceAmount: 150000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.warehouse,
    status: AssetStatus.active,
    addressLine: 'Industrial Zone',
    city: 'Addis Ababa',
    attributes: {'sqft': 5000},
    imageUrl:
        'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800&q=80',
    postedLabel: 'New · 3 hours ago',
    brokerId: 'b5',
  ),
  const Asset(
    id: '8',
    title: 'Two-bedroom condo, Sarbet',
    priceAmount: 6200000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.condominium,
    status: AssetStatus.active,
    addressLine: 'Sarbet Condominiums, Block 4',
    city: 'Addis Ababa',
    attributes: {'bedrooms': 2, 'bathrooms': 1, 'sqft': 980},
    imageUrl:
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80',
    postedLabel: 'New · 6 hours ago',
    brokerId: 'b4',
    rating: 4.6,
    reviewCount: 39,
    roiPercent: 8.2,
  ),
  const Asset(
    id: '9',
    title: 'Storage warehouse, Bole Lemi',
    priceAmount: 210000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.warehouse,
    status: AssetStatus.active,
    addressLine: 'Bole Lemi Industrial Park',
    city: 'Addis Ababa',
    attributes: {'sqft': 8500},
    imageUrl:
        'https://images.unsplash.com/photo-1553413077-190dd305871c?w=800&q=80',
    brokerId: 'b7',
  ),
  const Asset(
    id: '10',
    title: 'Reinforcement steel bars, bulk lot',
    priceAmount: 980000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.constructionMaterials,
    status: AssetStatus.active,
    addressLine: 'Akaki Steel Yard',
    city: 'Addis Ababa',
    attributes: {'condition': 'New', 'quantity': '12 tons'},
    imageUrl:
        'https://images.unsplash.com/photo-1541976590-713941681591?w=800&q=80',
    postedLabel: 'New · 4 hours ago',
    brokerId: 'b8',
  ),
  const Asset(
    id: '11',
    title: 'Isuzu FRR flatbed truck',
    priceAmount: 3100000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.vehicles,
    status: AssetStatus.active,
    addressLine: 'CMC Road, near Century Mall',
    city: 'Addis Ababa',
    attributes: {
      'year': 2018,
      'make': 'Isuzu',
      'model': 'FRR',
      'mileage': 62000
    },
    imageUrl:
        'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800&q=80',
    postedLabel: 'New · 8 hours ago',
    brokerId: 'b2',
  ),
  const Asset(
    id: '12',
    title: 'Komatsu D65 Bulldozer',
    priceAmount: 15200000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.machinery,
    status: AssetStatus.active,
    addressLine: 'CMC Road, near Century Mall',
    city: 'Addis Ababa',
    attributes: {'type': 'Bulldozer', 'year': 2017, 'hours': 5100},
    imageUrl:
        'https://images.unsplash.com/photo-1590496793929-36417d3117de?w=800&q=80',
    postedLabel: 'New · 9 hours ago',
    brokerId: 'b2',
  ),
  const Asset(
    id: '13',
    title: 'Modern Office Building, Addis Ababa',
    priceAmount: 2600000,
    priceCurrency: 'ETB',
    category: AssetCategorySlug.building,
    status: AssetStatus.active,
    addressLine: 'Nifas Silk, Business District',
    city: 'Addis Ababa',
    attributes: {'sqft': 5000},
    imageUrl:
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800&q=80',
    postedLabel: 'New · 12 hours ago',
    brokerId: 'b9',
  ),
];

/// Listings actually posted by a given broker (mock: matched by
/// `brokerId`). Real backend would filter server-side by `broker_id` FK.
List<Asset> assetsForBroker(String brokerId) {
  return kMockCompanyAssets.where((a) => a.brokerId == brokerId).toList();
}
