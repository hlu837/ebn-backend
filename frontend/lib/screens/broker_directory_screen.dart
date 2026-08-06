import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/broker.dart';
import '../services/agent_service.dart';
import '../services/map_config_service.dart';
import '../theme/landing_colors.dart';
import 'broker_map_screen.dart';
import 'broker_profile_screen.dart';

/// Landing point for the "Agents" bottom-tab / "Find Brokers" drawer item.
///
/// Two header choices — "Agent list" and "Map":
///  - Agent list: a scrollable list of every broker (avatar, name, company,
///    rating, tier badge), each row with its own small map icon. Tapping
///    that icon jumps to the Map tab with that one broker highlighted
///    boldly, while every other broker still shows up as a normal pin.
///  - Map: shows every broker as an equal-weight pin (no one bolded)
///    unless it was opened via a row's map icon, or a pin was tapped
///    directly on the map itself.
class BrokerDirectoryScreen extends StatefulWidget {
  final AssetCategorySlug category;
  final String categoryLabel;
  final bool showAllBrokers;

  /// The signed-in visitor, if any — threaded down to [BrokerProfileScreen]
  /// so "Chat" from a broker's profile opens a real conversation instead
  /// of falling back to sign-up. Only passed from logged-in entry points
  /// (`customer_home_screen.dart`'s "Broker List" tab); pre-login callers
  /// leave this null, which is correct since there's no session to chat as.
  final AppUser? currentUser;

  const BrokerDirectoryScreen({
    super.key,
    required this.category,
    required this.categoryLabel,
    this.showAllBrokers = false,
    this.currentUser,
  });

  @override
  State<BrokerDirectoryScreen> createState() => _BrokerDirectoryScreenState();
}

class _BrokerDirectoryScreenState extends State<BrokerDirectoryScreen> {
  int _tab = 0; // 0 = Agent list, 1 = Map
  Broker? _highlighted;

  final AgentService _agentService = AgentService();

  List<Broker> _brokers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBrokers();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _agentService.fetchDirectory(
        specialty: widget.showAllBrokers ? null : widget.category.slug,
      );
      final brokers = rows.map(Broker.fromDirectoryJson).toList();
      if (!mounted) return;
      setState(() {
        _brokers = brokers;
        _loading = false;
      });
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _openProfile(Broker broker) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrokerProfileScreen(broker: broker, currentUser: widget.currentUser),
    ));
  }

  void _showOnMap(Broker broker) {
    setState(() {
      _highlighted = broker;
      _tab = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brokers = _brokers;

    return Scaffold(
      backgroundColor: LandingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _DirectoryHeader(
              categoryLabel: widget.categoryLabel,
              tab: _tab,
              onTabChanged: (i) => setState(() => _tab = i),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _DirectoryErrorState(message: _error!, onRetry: _loadBrokers)
                      : _tab == 0
                          ? _BrokerListView(
                              brokers: brokers,
                              onOpenProfile: _openProfile,
                              onShowOnMap: _showOnMap,
                            )
                          : _DirectoryMapView(
                              brokers: brokers,
                              highlighted: _highlighted,
                              onSelect: (b) => setState(() => _highlighted = b),
                              onOpenProfile: _openProfile,
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DirectoryErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: LandingColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LandingColors.muted, fontSize: 13.5)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Title + subtitle + the "Agent list / Map" segmented toggle, laid out to
/// match the reference: bold title top-left, a pill segmented control
/// top-right, descriptive subtitle underneath.
class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.categoryLabel,
    required this.tab,
    required this.onTabChanged,
    required this.onBack,
  });

  final String categoryLabel;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.only(right: 6, top: 2, bottom: 2),
                  child: Icon(Icons.arrow_back, size: 22, color: LandingColors.foreground),
                ),
              ),
              Expanded(
                child: Text(
                  '$categoryLabel brokers',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: LandingColors.foreground,
                  ),
                ),
              ),
              _SegmentedToggle(value: tab, onChanged: onTabChanged),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Verified agents who can help you close this deal.',
            style: TextStyle(fontSize: 14.5, color: LandingColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Two-way pill switcher: "List" vs "Map" — the "two header choices".
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LandingColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandingColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            icon: Icons.list_rounded,
            label: 'List',
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
          _SegmentButton(
            icon: Icons.map_outlined,
            label: 'Map',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? LandingColors.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? LandingColors.primaryFg : LandingColors.muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? LandingColors.primaryFg : LandingColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrollable list of every broker, one row each.
class _BrokerListView extends StatelessWidget {
  const _BrokerListView({
    required this.brokers,
    required this.onOpenProfile,
    required this.onShowOnMap,
  });

  final List<Broker> brokers;
  final ValueChanged<Broker> onOpenProfile;
  final ValueChanged<Broker> onShowOnMap;

  @override
  Widget build(BuildContext context) {
    if (brokers.isEmpty) {
      return const Center(
        child: Text('No brokers found for this category yet.',
            style: TextStyle(color: LandingColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: brokers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: LandingColors.border),
      itemBuilder: (context, i) => _BrokerRow(
        broker: brokers[i],
        onTap: () => onOpenProfile(brokers[i]),
        onMapTap: () => onShowOnMap(brokers[i]),
      ),
    );
  }
}

class _BrokerRow extends StatelessWidget {
  const _BrokerRow({required this.broker, required this.onTap, required this.onMapTap});

  final Broker broker;
  final VoidCallback onTap;
  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: LandingColors.gold, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                broker.initials,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LandingColors.goldFg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    broker.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LandingColors.foreground),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${broker.company} · ${broker.city}',
                    style: const TextStyle(fontSize: 13.5, color: LandingColors.muted, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: LandingColors.gold),
                      const SizedBox(width: 3),
                      Text(
                        broker.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: LandingColors.foreground),
                      ),
                      const SizedBox(width: 10),
                      Icon(broker.tier.icon, size: 15, color: broker.tier.color),
                      const SizedBox(width: 3),
                      Text(
                        broker.tier.label,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: broker.tier.color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onMapTap,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.map_outlined, size: 20, color: LandingColors.foreground),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 22, color: LandingColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Reuses the pin/background/preview-card widgets from [BrokerMapScreen] so
/// the map itself stays visually identical between the two entry points.
/// Fetches the Gebeta Maps API key from the backend and renders a real
/// interactive map when available; falls back to the painted placeholder
/// when the backend isn't reachable or the key isn't configured.
class _DirectoryMapView extends StatefulWidget {
  const _DirectoryMapView({
    required this.brokers,
    required this.highlighted,
    required this.onSelect,
    required this.onOpenProfile,
  });

  final List<Broker> brokers;
  final Broker? highlighted;
  final ValueChanged<Broker> onSelect;
  final ValueChanged<Broker> onOpenProfile;

  @override
  State<_DirectoryMapView> createState() => _DirectoryMapViewState();
}

class _DirectoryMapViewState extends State<_DirectoryMapView> {
  late Future<MapConfig> _mapConfigFuture;

  @override
  void initState() {
    super.initState();
    _mapConfigFuture = MapConfigService().fetchConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.brokers.isEmpty) {
      return const Center(
        child: Text('No brokers found for this category yet.',
            style: TextStyle(color: LandingColors.muted)),
      );
    }

    final lats = widget.brokers.map((b) => b.latitude).toList();
    final lngs = widget.brokers.map((b) => b.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return Stack(
      children: [
        // ── Map layer (real or fallback) ──────────────────────────
        Positioned.fill(
          child: FutureBuilder<MapConfig>(
            future: _mapConfigFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(
                  color: Color(0xFFE9E4D6),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (kIsWeb || snapshot.hasError || !snapshot.hasData) {
                // Fallback: interactive painted map with positioned pins for Web or missing key.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        const Positioned.fill(child: BrokerMapBackground()),
                        ...widget.brokers.map((b) {
                          final offset = _project(
                            b.latitude, b.longitude,
                            minLat, maxLat, minLng, maxLng,
                            constraints.biggest,
                          );
                          final isSelected = widget.highlighted?.id == b.id;
                          return Positioned(
                            left: offset.dx - 20,
                            top: offset.dy - 44,
                            child: BrokerMapPin(
                              broker: b,
                              selected: isSelected,
                              onTap: () => widget.onSelect(b),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              }
              // Real Gebeta Maps tiles + circle markers.
              return RealBrokerMap(
                config: snapshot.data!,
                brokers: widget.brokers,
                selected: widget.highlighted,
                onBrokerTapped: widget.onSelect,
              );
            },
          ),
        ),
        // ── Bottom preview card ──────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: widget.highlighted == null
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: LandingColors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Text(
                      'Tap a pin to see that broker\'s details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: LandingColors.muted, fontSize: 12.5),
                    ),
                  )
                : BrokerPreviewCard(broker: widget.highlighted!),
          ),
        ),
      ],
    );
  }

  Offset _project(double lat, double lng, double minLat, double maxLat, double minLng, double maxLng, Size size) {
    const padding = 46.0;
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final nx = lngSpan == 0 ? 0.5 : (lng - minLng) / lngSpan;
    final ny = latSpan == 0 ? 0.5 : 1 - (lat - minLat) / latSpan;
    final dx = padding + nx * (size.width - padding * 2);
    final dy = padding + ny * (size.height - padding * 2);
    return Offset(dx, dy);
  }
}
