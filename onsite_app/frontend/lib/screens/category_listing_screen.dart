import 'package:flutter/material.dart';
import '../models/broker.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/user_role.dart';
import '../services/agent_service.dart';
import '../services/asset_service.dart';
import '../theme/landing_colors.dart';
import '../widgets/asset_list_card.dart';
import '../widgets/sell_or_meet_broker_card.dart';
import 'asset_detail_screen.dart';
import 'broker_map_screen.dart';
import 'broker_profile_screen.dart';

const _kGuestUser = AppUser(
  id: 'guest',
  fullName: 'Guest User',
  email: 'guest@ebn.et',
  role: UserRole.user,
);

/// Category detail page reached by tapping a tile in the landing page's
/// category grid. Shows a search bar, a horizontally-scrollable strip of
/// listings in that category, and a way to pull up nearby brokers who
/// specialize in it.
class CategoryListingScreen extends StatefulWidget {
  final AssetCategorySlug category;
  final String categoryLabel;
  final IconData categoryIcon;
  final VoidCallback onGetStarted;

  /// Extra categories folded into this page's listings/brokers, for tiles
  /// that were removed from the landing grid but still need a home — e.g.
  /// Apartments, Condominium, and Building all surface here under House.
  final List<AssetCategorySlug> extraCategories;

  /// Whether to show the "Sell it here / Meet a broker" prompt card at the
  /// top of the listings. Defaults to true for the anonymous marketing flow
  /// (role_gate_screen); the signed-in Visitor dashboard passes false since
  /// that card now lives at the bottom of the dashboard instead.
  final bool showSellCard;

  const CategoryListingScreen({
    super.key,
    required this.category,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.onGetStarted,
    this.extraCategories = const [],
    this.showSellCard = true,
  });

  @override
  State<CategoryListingScreen> createState() => _CategoryListingScreenState();
}

enum _SortOption { relevance, priceLowHigh, priceHighLow }

extension _SortOptionX on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.relevance:
        return 'Relevance';
      case _SortOption.priceLowHigh:
        return 'Price: Low to High';
      case _SortOption.priceHighLow:
        return 'Price: High to Low';
    }
  }
}

class _CategoryListingScreenState extends State<CategoryListingScreen> {
  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  String _query = '';
  double? _minPrice;
  double? _maxPrice;
  _SortOption _sort = _SortOption.relevance;
  bool _searchOpen = false;

  bool get _hasActiveFilters =>
      _minPrice != null || _maxPrice != null || _sort != _SortOption.relevance;

  final AssetService _assetService = AssetService();
  final AgentService _agentService = AgentService();

  // Populated from the real `GET /api/assets` response once it lands.
  List<Asset> _allAssets = [];
  bool _loading = true;
  String? _error;

  // Populated from the real `GET /api/agents` response. Keyed by user id
  // so `_brokerFor` can resolve a listing's `broker_id` directly — there's
  // no join on the backend yet, so this is a client-side lookup built
  // once per screen load rather than per-listing.
  Map<String, Broker> _brokersById = {};
  List<Broker> _allBrokers = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _loadBrokers();
  }

  Future<void> _loadBrokers() async {
    try {
      final rows = await _agentService.fetchDirectory();
      final brokers = rows.map(Broker.fromDirectoryJson).toList();
      if (!mounted) return;
      setState(() {
        _allBrokers = brokers;
        _brokersById = {for (final b in brokers) b.id: b};
      });
    } on AgentServiceException catch (_) {
      // Leave the maps empty — `_brokerFor` already handles "no broker
      // found" by returning null rather than assuming a fallback.
    }
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assets = await _assetService.fetchAssets(limit: 200);
      if (!mounted) return;
      setState(() {
        _allAssets = assets;
        _loading = false;
      });
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  List<AssetCategorySlug> get _allCategories =>
      [widget.category, ...widget.extraCategories];

  List<Asset> get _assets {
    final q = _query.trim().toLowerCase();
    final categories = _allCategories;
    final list = _allAssets.where((a) {
      if (!categories.contains(a.category)) return false;
      if (_minPrice != null && a.priceAmount < _minPrice!) return false;
      if (_maxPrice != null && a.priceAmount > _maxPrice!) return false;
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          (a.city ?? '').toLowerCase().contains(q) ||
          (a.addressLine ?? '').toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _SortOption.relevance:
        break;
      case _SortOption.priceLowHigh:
        list.sort((a, b) => a.priceAmount.compareTo(b.priceAmount));
        break;
      case _SortOption.priceHighLow:
        list.sort((a, b) => b.priceAmount.compareTo(a.priceAmount));
        break;
    }
    return list;
  }

  Future<void> _openFilters(BuildContext context) async {
    _minPriceController.text =
        _minPrice == null ? '' : _minPrice!.toStringAsFixed(0);
    _maxPriceController.text =
        _maxPrice == null ? '' : _maxPrice!.toStringAsFixed(0);
    var sheetSort = _sort;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LandingColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filters',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: LandingColors.foreground)),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            sheetSort = _SortOption.relevance;
                            _minPriceController.clear();
                            _maxPriceController.clear();
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(
                                color: LandingColors.muted,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Sort by',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: LandingColors.foreground)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SortOption.values.map((option) {
                      final selected = sheetSort == option;
                      return ChoiceChip(
                        label: Text(option.label),
                        selected: selected,
                        onSelected: (_) =>
                            setSheetState(() => sheetSort = option),
                        labelStyle: TextStyle(
                          color: selected
                              ? LandingColors.goldFg
                              : LandingColors.foreground,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        backgroundColor: LandingColors.card,
                        selectedColor: LandingColors.gold,
                        side: const BorderSide(color: LandingColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Price range',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: LandingColors.foreground)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Min',
                            hintStyle:
                                const TextStyle(color: LandingColors.muted),
                            filled: true,
                            fillColor: LandingColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.gold, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('–',
                          style: TextStyle(color: LandingColors.muted)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max',
                            hintStyle:
                                const TextStyle(color: LandingColors.muted),
                            filled: true,
                            fillColor: LandingColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: LandingColors.gold, width: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sort = sheetSort;
                        _minPrice =
                            double.tryParse(_minPriceController.text.trim());
                        _maxPrice =
                            double.tryParse(_maxPriceController.text.trim());
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LandingColors.gold,
                      foregroundColor: LandingColors.goldFg,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Apply filters',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Resolves the broker tied to a listing from the real directory loaded
  /// in [_loadBrokers]. Returns null — rather than a mock stand-in — when
  /// the listing's `broker_id` doesn't match any real agent account, or
  /// when no broker in the loaded directory covers this category at all;
  /// callers need to handle that (see the listing card and finder sheet
  /// below) instead of silently showing someone unrelated.
  Broker? _brokerFor(Asset asset) {
    final direct = asset.brokerId != null ? _brokersById[asset.brokerId] : null;
    if (direct != null) return direct;
    for (final c in _allCategories) {
      final candidates =
          _allBrokers.where((b) => b.specialties.contains(c)).toList();
      if (candidates.isNotEmpty) return candidates.first;
    }
    return null;
  }

  void _openBrokerFinder(BuildContext context) {
    final seen = <String>{};
    final brokers = <Broker>[];
    for (final c in _allCategories) {
      for (final b in _allBrokers.where((b) => b.specialties.contains(c))) {
        if (seen.add(b.id)) brokers.add(b);
      }
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: LandingColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _BrokerFinderSheet(
        category: widget.category,
        categoryLabel: widget.categoryLabel,
        brokers: brokers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    return Scaffold(
      backgroundColor: LandingColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_searchOpen) {
                        setState(() {
                          _searchOpen = false;
                          _query = '';
                          _searchController.clear();
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(_searchOpen ? Icons.close : Icons.arrow_back,
                        color: const Color(0xFFFF2636)),
                  ),
                  if (_searchOpen) ...[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                        cursorColor: const Color(0xFFFF2636),
                        decoration: InputDecoration(
                          hintText:
                              'Search ${widget.categoryLabel.toLowerCase()}...',
                          hintStyle: const TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF2636).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Icon(widget.categoryIcon,
                          size: 18, color: const Color(0xFFFF2636)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.categoryLabel,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                    ),
                  ],
                  IconButton(
                    onPressed: () => setState(() => _searchOpen = true),
                    icon: const Icon(Icons.search, color: Color(0xFFFF2636)),
                  ),
                  Material(
                    color: _hasActiveFilters
                        ? const Color(0xFFFF2636)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: _hasActiveFilters
                              ? const Color(0xFFFF2636)
                              : Colors.black12),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openFilters(context),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _hasActiveFilters
                              ? Colors.white
                              : const Color(0xFFFF2636),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const SizedBox(height: 4),
                  if (widget.showSellCard) ...[
                    SellOrMeetBrokerCard(
                      title:
                          'Have a ${widget.categoryLabel.toLowerCase()} to sell?',
                      onSell: widget.onGetStarted,
                      onMeetBroker: () => _openBrokerFinder(context),
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (!_loading && _error == null)
                    Text(
                        '${assets.length} listing${assets.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: LandingColors.muted)),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Container(
                      decoration: BoxDecoration(
                        color: LandingColors.card,
                        border: Border.all(color: LandingColors.border),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 34, color: LandingColors.muted),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: LandingColors.muted)),
                          const SizedBox(height: 14),
                          OutlinedButton(
                              onPressed: _loadAssets,
                              child: const Text('Try again')),
                        ],
                      ),
                    )
                  else if (assets.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: LandingColors.card,
                        border: Border.all(color: LandingColors.border),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      alignment: Alignment.center,
                      child: const Text('No listings match your search yet.',
                          style: TextStyle(color: LandingColors.muted)),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.48,
                      ),
                      itemCount: assets.length,
                      itemBuilder: (context, i) {
                        return AssetListCard(
                          asset: assets[i],
                          compact: true,
                          showCategoryPill: false,
                          brokerInitials: _brokerFor(assets[i])?.initials,
                          onBrokerAvatarTap: () {
                            final broker = _brokerFor(assets[i]);
                            if (broker == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "No agent info for this listing yet.")),
                              );
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  BrokerProfileScreen(broker: broker),
                            ));
                          },
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AssetDetailScreen(
                                asset: assets[i],
                                user: _kGuestUser,
                              ),
                            ));
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrokerFinderSheet extends StatelessWidget {
  final AssetCategorySlug category;
  final String categoryLabel;
  final List<Broker> brokers;
  const _BrokerFinderSheet(
      {required this.category,
      required this.categoryLabel,
      required this.brokers});

  void _openMap(BuildContext context, {Broker? highlight}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrokerMapScreen(
          category: category,
          categoryLabel: categoryLabel,
          highlightBroker: highlight),
    ));
  }

  void _openProfile(BuildContext context, Broker broker) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrokerProfileScreen(broker: broker),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: LandingColors.border,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$categoryLabel brokers',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: LandingColors.foreground)),
                      const SizedBox(height: 4),
                      const Text(
                          'Verified agents who can help you close this deal.',
                          style: TextStyle(
                              fontSize: 13, color: LandingColors.muted)),
                    ],
                  ),
                ),
                Material(
                  color: LandingColors.foreground,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openMap(context),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.map_rounded,
                              size: 16, color: LandingColors.primaryFg),
                          SizedBox(width: 6),
                          Text('Map',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: LandingColors.primaryFg)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (brokers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No verified agents for this category yet.',
                  style: TextStyle(color: LandingColors.muted, fontSize: 13.5),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: brokers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: LandingColors.border),
                  itemBuilder: (_, i) {
                    final broker = brokers[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openProfile(context, broker),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                    color: LandingColors.gold,
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(broker.initials,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: LandingColors.goldFg)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(broker.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: LandingColors.foreground,
                                            fontSize: 14.5)),
                                    const SizedBox(height: 2),
                                    Text('${broker.company} · ${broker.city}',
                                        style: const TextStyle(
                                            color: LandingColors.muted,
                                            fontSize: 12.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            size: 14,
                                            color: LandingColors.gold),
                                        const SizedBox(width: 2),
                                        Text(broker.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: LandingColors.muted)),
                                        const SizedBox(width: 8),
                                        Icon(broker.tier.icon,
                                            size: 13, color: broker.tier.color),
                                        const SizedBox(width: 2),
                                        Text(broker.tier.label,
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: broker.tier.color)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    _openMap(context, highlight: broker),
                                icon: const Icon(Icons.map_outlined,
                                    color: LandingColors.foreground),
                                tooltip: 'View on map',
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: LandingColors.muted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
