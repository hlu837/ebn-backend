import 'package:flutter/material.dart';
import 'role_select_screen.dart';
import 'login_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'faq_screen.dart';
import 'how_it_works_screen.dart';
import 'membership_screen.dart';
import 'platform_features_screen.dart';
import 'category_listing_screen.dart';
import 'broker_map_screen.dart';
import 'order_request_form_screen.dart';
import 'sell_property_form_screen.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/user_role.dart';
import '../services/asset_service.dart';
import '../services/mock_asset_data.dart';
import '../widgets/order_category_sheet.dart';
import 'asset_detail_screen.dart';

const _kGuestUser = AppUser(
  id: 'guest',
  fullName: 'Guest User',
  email: 'guest@ebn.et',
  role: UserRole.user,
);

class EBNColors {
  static const red = Color(0xFFFF2636);
  static const darkCard = Color(0xFF1C1E22);
  static const green = Color(0xFF1E8E3E);
  static const grey = Color(0xFF8A8D93);
  static const lightGrey = Color(0xFFF0F0F2);
  static const border = Color(0xFFE7E7EA);
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------

class QuickAction {
  final IconData icon;
  final String label;
  final bool highlighted;
  const QuickAction(this.icon, this.label, {this.highlighted = false});
}

class TrendingAd {
  final String imageUrl;
  final String price;
  final String title;
  final String location;
  final List<String> tags;
  final String sellerName;
  final String sellerAvatarUrl;
  final bool isNew;
  final AssetCategorySlug? categorySlug;

  const TrendingAd({
    required this.imageUrl,
    required this.price,
    required this.title,
    required this.location,
    required this.tags,
    required this.sellerName,
    required this.sellerAvatarUrl,
    this.isNew = false,
    this.categorySlug,
  });
}

// ---------------------------------------------------------------------------
// PAGE
// ---------------------------------------------------------------------------

class EBNLandingPage extends StatefulWidget {
  final VoidCallback? onOpenSearch;

  const EBNLandingPage({
    super.key,
    this.onOpenSearch,
  });

  @override
  State<EBNLandingPage> createState() => _EBNLandingPageState();
}

class _EBNLandingPageState extends State<EBNLandingPage> {
  int _selectedTab = 0;
  final int _bannerIndex = 0;

  final AssetService _assetService = AssetService();

  // Painted instantly from the bundled mock list so trending tiles always
  // have something to open, then swapped for the real `GET /api/assets`
  // response the moment it lands.
  List<Asset> _assets = List.of(kMockCompanyAssets);

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await _assetService.fetchAssets(limit: 200);
      if (!mounted) return;
      setState(() => _assets = assets);
    } on AssetException catch (_) {
      // Backend down / unreachable — keep showing the bundled mock listings.
    }
  }

  final List<String> _tabs = const [
    'For You',
    'Vehicles',
    'Real Estate',
    'Machinery'
  ];

  final List<QuickAction> _actions = const [
    QuickAction(Icons.add, 'Post Ad', highlighted: true),
    QuickAction(Icons.directions_car_outlined, 'Vehicles'),
    QuickAction(Icons.terrain_outlined, 'Machinery'),
    QuickAction(Icons.home_outlined, 'House'),
    QuickAction(Icons.warehouse_outlined, 'Warehouse'),
    QuickAction(Icons.landscape_outlined, 'Land'),
    QuickAction(Icons.swap_horiz, 'Materials'),
    QuickAction(Icons.groups_outlined, 'Brokers'),
  ];

  final List<TrendingAd> _ads = const [
    TrendingAd(
      imageUrl: 'https://picsum.photos/seed/ebn-house/400/300',
      price: 'ETB 45,000',
      title: 'Modern luxury family home with garden',
      location: 'Addis Ababa',
      tags: ['4 bd', '3 ba'],
      sellerName: 'Biniam T.',
      sellerAvatarUrl: 'https://i.pravatar.cc/64?img=12',
      isNew: true,
      categorySlug: AssetCategorySlug.house,
    ),
    TrendingAd(
      imageUrl: 'https://picsum.photos/seed/ebn-car/400/300',
      price: 'ETB 4.2M',
      title: '2022 Toyota Camry SE Dark Gray',
      location: 'Bole, Addis Ababa',
      tags: ['Used', 'Auto'],
      sellerName: 'Samuel L.',
      sellerAvatarUrl: 'https://i.pravatar.cc/64?img=33',
      categorySlug: AssetCategorySlug.vehicles,
    ),
    TrendingAd(
      imageUrl: 'https://picsum.photos/seed/ebn-excavator/400/300',
      price: 'ETB 18.5M',
      title: 'CAT 320 Excavator Heavy Duty',
      location: 'Addis Ababa',
      tags: ['Heavy', '2021'],
      sellerName: 'Equip Sales',
      sellerAvatarUrl: 'https://i.pravatar.cc/64?img=5',
      categorySlug: AssetCategorySlug.machinery,
    ),
    TrendingAd(
      imageUrl: 'https://picsum.photos/seed/ebn-studio/400/300',
      price: 'ETB 18,000',
      title: 'Studio near Bole Rd - Furnished',
      location: 'Bole, Addis Ababa',
      tags: ['1 bd', 'WiFi'],
      sellerName: 'Hanna M.',
      sellerAvatarUrl: 'https://i.pravatar.cc/64?img=45',
      categorySlug: AssetCategorySlug.house,
    ),
  ];

  void _goToCategory(AssetCategorySlug slug, String label, IconData icon) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryListingScreen(
        category: slug,
        categoryLabel: label,
        categoryIcon: icon,
        onGetStarted: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const RoleSelectScreen(),
          ));
        },
      ),
    ));
  }

  void _openOrderFlow() async {
    final category = await showOrderCategorySheet(context);
    if (category != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderRequestFormScreen(
          user: _kGuestUser,
          category: category,
        ),
      ));
    }
  }

  void _openSellFlow() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SellPropertyFormScreen(user: _kGuestUser),
    ));
  }

  void _handleQuickAction(int index) {
    switch (index) {
      case 0: // Post Ad
        _openSellFlow();
        break;
      case 1: // Vehicles
        _goToCategory(AssetCategorySlug.vehicles, 'Vehicles',
            Icons.directions_car_outlined);
        break;
      case 2: // Machinery
        _goToCategory(
            AssetCategorySlug.machinery, 'Machinery', Icons.terrain_outlined);
        break;
      case 3: // House
        _goToCategory(AssetCategorySlug.house, 'House', Icons.home_outlined);
        break;
      case 4: // Warehouse
        _goToCategory(
            AssetCategorySlug.warehouse, 'Warehouse', Icons.warehouse_outlined);
        break;
      case 5: // Land
        _goToCategory(AssetCategorySlug.others, 'Land', Icons.landscape_outlined);
        break;
      case 6: // Materials
        _goToCategory(AssetCategorySlug.constructionMaterials,
            'Construction Materials', Icons.swap_horiz);
        break;
      case 7: // Brokers
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const BrokerMapScreen(
            category: AssetCategorySlug.others,
            categoryLabel: 'All',
            showAllBrokers: true,
          ),
        ));
        break;
    }
  }

  void _handleTabSelect(int index) {
    setState(() => _selectedTab = index);
    if (index == 1) {
      // Vehicles
      _goToCategory(AssetCategorySlug.vehicles, 'Vehicles',
          Icons.directions_car_outlined);
    } else if (index == 2) {
      // Real Estate
      _goToCategory(
          AssetCategorySlug.house, 'Real Estate', Icons.home_outlined);
    } else if (index == 3) {
      // Machinery
      _goToCategory(
          AssetCategorySlug.machinery, 'Machinery', Icons.terrain_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabs(),
            _buildSafetyBanner(),
            _buildInspectionBanner(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 8),
            _buildOrderSellRow(),
            const SizedBox(height: 24),
            _buildTrendingHeader(),
            _buildTrendingGrid(),
            const SizedBox(height: 32),
            _buildCTASection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // --- Bottom Navigation Bar -------------------------------------------------

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: EBNColors.border, width: 1),
        ),
      ),
      child: BottomAppBar(
        elevation: 0,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              icon: Icons.add_circle_outline,
              label: 'Post Ad',
              onTap: () => _handleQuickAction(0),
            ),
            _buildBottomNavItem(
              icon: Icons.directions_car_outlined,
              label: 'Vehicles',
              onTap: () => _handleQuickAction(1),
            ),
            _buildBottomNavItem(
              icon: Icons.home_outlined,
              label: 'Real Estate',
              onTap: () => _handleQuickAction(3),
            ),
            _buildBottomNavItem(
              icon: Icons.terrain_outlined,
              label: 'Machinery',
              onTap: () => _handleQuickAction(2),
            ),
            _buildBottomNavItem(
              icon: Icons.people_outlined,
              label: 'Brokers',
              onTap: () => _handleQuickAction(7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: EBNColors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: EBNColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Header --------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'EBN',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: EBNColors.red,
                  side: const BorderSide(color: EBNColors.red, width: 1.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Log In',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search, size: 24),
                onPressed: widget.onOpenSearch,
              ),
              IconButton(
                icon: const Icon(Icons.language, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Language selector: English (default)')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Search bar ------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: widget.onOpenSearch,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: EBNColors.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: EBNColors.grey, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search homes, vehicles, machinery on EBN...',
                  style: TextStyle(color: EBNColors.grey, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Category tabs ---------------------------------------------------------

  Widget _buildTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final selected = index == _selectedTab;
          return GestureDetector(
            onTap: () => _handleTabSelect(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? EBNColors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? null
                    : Border.all(color: EBNColors.border, width: 1),
              ),
              child: Text(
                _tabs[index],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Safety strip ------------------------------------------------------------

  Widget _buildSafetyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFDEDEB),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined,
              color: EBNColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: 12.5, color: Colors.black87, height: 1.4),
                children: [
                  TextSpan(
                    text: 'Stay safe with verified listings. ',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: EBNColors.red),
                  ),
                  TextSpan(
                    text:
                        'Request an on-site inspection before making transactions.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dark promo / inspection carousel card ------------------------------------

  Widget _buildInspectionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: EBNColors.darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 8, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Verified\nInspection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Get peace of mind with expert reporting.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _openOrderFlow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EBNColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Request Now',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 190,
                  child: Image.network(
                    'https://picsum.photos/seed/ebn-inspector/300/300',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.verified,
                            color: Colors.white54, size: 48),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 12,
            left: 20,
            child: Row(
              children: List.generate(3, (i) {
                final active = i == _bannerIndex;
                return Container(
                  margin: const EdgeInsets.only(right: 5),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: active ? 1 : 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- Quick action grid -------------------------------------------------------

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 18,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final action = _actions[index];
          return GestureDetector(
            onTap: () => _handleQuickAction(index),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0EE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    color: const Color(0xFF4A4A45),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Order us / Sell with us cards --------------------------------------------

  Widget _buildOrderSellRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openOrderFlow,
              child: _infoCard(
                icon: Icons.verified_outlined,
                title: 'Order us',
                subtitle: 'get what you want',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _openSellFlow,
              child: _infoCard(
                icon: Icons.attach_money,
                title: 'Sell With Us',
                subtitle: 'Meet a broker',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EBNColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0EE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF4A4A45)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: EBNColors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Trending ads --------------------------------------------------------------

  Widget _buildTrendingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Trending Ads',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          GestureDetector(
            onTap: () {
              _goToCategory(AssetCategorySlug.house, 'All Trending Ads',
                  Icons.trending_up);
            },
            child: const Row(
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    color: EBNColors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.chevron_right, color: EBNColors.green, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _ads.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.55,
        ),
        itemBuilder: (context, index) {
          final ad = _ads[index];
          return GestureDetector(
            onTap: () {
              if (_assets.isEmpty) return;
              final mockAsset = _assets.firstWhere(
                (a) => a.category == ad.categorySlug,
                orElse: () => _assets.first,
              );
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    AssetDetailScreen(asset: mockAsset, user: _kGuestUser),
              ));
            },
            child: _AdCard(ad: ad),
          );
        },
      ),
    );
  }

  // --- CTA + footer -----------------------------------------------------------

  Widget _buildCTASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'Ready to verify with\nconfidence?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 10),
          const Text(
            'Join thousands of users securing their future today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: EBNColors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RoleSelectScreen(),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: EBNColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started / Sign Up',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// AD CARD WIDGET
// ---------------------------------------------------------------------------

class _AdCard extends StatelessWidget {
  final TrendingAd ad;
  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EBNColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.2,
                child: Image.network(
                  ad.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child:
                          const Icon(Icons.image, color: Colors.grey, size: 36),
                    );
                  },
                ),
              ),
              if (ad.isNew)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: EBNColors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border,
                      size: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.price,
                  style: const TextStyle(
                    color: EBNColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: EBNColors.grey),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        ad.location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: EBNColors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundImage: NetworkImage(ad.sellerAvatarUrl),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ad.sellerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: EBNColors.border),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: const Icon(Icons.share_outlined,
                        size: 16, color: EBNColors.grey),
                  ),
                ),
                Container(width: 1, height: 20, color: EBNColors.border),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: const Icon(Icons.message_outlined,
                        size: 16, color: EBNColors.grey),
                  ),
                ),
                Container(width: 1, height: 20, color: EBNColors.border),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: const Icon(Icons.more_horiz,
                        size: 16, color: EBNColors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
