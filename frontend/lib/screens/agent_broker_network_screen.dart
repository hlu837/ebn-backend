import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/broker.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../services/asset_service.dart';
import '../services/map_config_service.dart';
import '../theme/app_theme.dart';
import 'broker_map_screen.dart';

/// Browse every other broker/agent on the platform, filter by specialty or
/// city, and reach out directly — the agent-facing counterpart to the
/// visitor-facing [BrokerDirectoryScreen], styled to match the rest of the
/// agent workspace instead of the public landing theme.
///
/// Same "List / Map" toggle as the visitor directory, plus a "Nearest"
/// sort that ranks brokers by distance from the signed-in agent's own
/// saved location (fetched via a self-lookup on the same `/api/agents`
/// directory endpoint, [Broker.hasPreciseLocation] gating whether that's
/// possible at all).
class AgentBrokerNetworkScreen extends StatefulWidget {
  const AgentBrokerNetworkScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentBrokerNetworkScreen> createState() => _AgentBrokerNetworkScreenState();
}

enum _SortMode { nearest, rating }

/// Haversine great-circle distance in km — mirrors the SQL formula used
/// server-side in `users.js`'s `findNearbyAgents`, so "nearest" here
/// matches what the dispatch system itself considers nearby.
double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _radians(double deg) => deg * math.pi / 180;

String _formatDistance(double km) => km < 1 ? '${(km * 1000).round()} m away' : '${km.toStringAsFixed(1)} km away';

class _AgentBrokerNetworkScreenState extends State<AgentBrokerNetworkScreen> {
  final TextEditingController _search = TextEditingController();
  AssetCategorySlug? _specialtyFilter;
  int _tab = 0; // 0 = list, 1 = map
  _SortMode _sortMode = _SortMode.rating;
  Broker? _highlighted;

  final AgentService _agentService = AgentService();
  List<Broker> _brokers = const [];
  bool _loading = true;
  String? _error;

  /// This agent's own saved location, resolved via a self-lookup
  /// (`userId: widget.user.id`) against the same directory endpoint.
  /// Null if the agent hasn't set a location yet or the lookup fails —
  /// "Nearest" sort/distances just aren't offered in that case.
  double? _selfLat;
  double? _selfLng;

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
      final results = await Future.wait([
        _agentService.fetchDirectory(excludeUserId: widget.user.id),
        _agentService.fetchDirectory(userId: widget.user.id),
      ]);
      final brokers = results[0].map(Broker.fromDirectoryJson).toList();
      final self = results[1].map(Broker.fromDirectoryJson).toList();
      if (!mounted) return;
      setState(() {
        _brokers = brokers;
        if (self.isNotEmpty && self.first.hasPreciseLocation) {
          _selfLat = self.first.latitude;
          _selfLng = self.first.longitude;
          _sortMode = _SortMode.nearest;
        } else {
          _selfLat = null;
          _selfLng = null;
          _sortMode = _SortMode.rating;
        }
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

  double? _distanceTo(Broker b) {
    final lat = _selfLat, lng = _selfLng;
    if (lat == null || lng == null || !b.hasPreciseLocation) return null;
    return _distanceKm(lat, lng, b.latitude, b.longitude);
  }

  void _showOnMap(Broker broker) {
    setState(() {
      _highlighted = broker;
      _tab = 1;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var brokers = _brokers;

    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      brokers = brokers.where((b) => b.name.toLowerCase().contains(query) || b.company.toLowerCase().contains(query) || b.city.toLowerCase().contains(query)).toList();
    }
    if (_specialtyFilter != null) {
      brokers = brokers.where((b) => b.specialties.contains(_specialtyFilter)).toList();
    }
    if (_sortMode == _SortMode.nearest && _selfLat != null) {
      brokers.sort((a, b) {
        final da = _distanceTo(a) ?? double.infinity;
        final db = _distanceTo(b) ?? double.infinity;
        return da.compareTo(db);
      });
    } else {
      brokers.sort((a, b) => b.rating.compareTo(a.rating));
    }

    final specialties = _brokers.expand((b) => b.specialties).toSet().toList()..sort((a, b) => a.label.compareTo(b.label));

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Broker Network', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: _ListMapToggle(value: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name, company, or city',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.slate), onPressed: () => setState(_search.clear)),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                if (_selfLat != null) ...[
                  _SpecialtyChip(
                    label: 'Nearest',
                    icon: Icons.near_me_rounded,
                    selected: _sortMode == _SortMode.nearest,
                    onTap: () => setState(() => _sortMode = _SortMode.nearest),
                  ),
                  const SizedBox(width: 8),
                  _SpecialtyChip(
                    label: 'Top rated',
                    icon: Icons.star_rounded,
                    selected: _sortMode == _SortMode.rating,
                    onTap: () => setState(() => _sortMode = _SortMode.rating),
                  ),
                  const SizedBox(width: 12),
                  const VerticalDivider(width: 1, indent: 6, endIndent: 6, color: AppColors.border),
                  const SizedBox(width: 4),
                ],
                _SpecialtyChip(label: 'All', selected: _specialtyFilter == null, onTap: () => setState(() => _specialtyFilter = null)),
                for (final s in specialties) ...[
                  const SizedBox(width: 8),
                  _SpecialtyChip(label: s.label, selected: _specialtyFilter == s, onTap: () => setState(() => _specialtyFilter = s)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.slate),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
                              const SizedBox(height: 12),
                              OutlinedButton(onPressed: _loadBrokers, child: const Text('Try again')),
                            ],
                          ),
                        ),
                      )
                    : brokers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: Text('No brokers match this search.', style: TextStyle(fontSize: 13.5, color: AppColors.slate)),
                            ),
                          )
                        : _tab == 0
                            ? ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                                itemCount: brokers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, i) => _BrokerCard(
                                  broker: brokers[i],
                                  distanceKm: _distanceTo(brokers[i]),
                                  onShowOnMap: () => _showOnMap(brokers[i]),
                                ),
                              )
                            : _AgentMapView(
                                brokers: brokers,
                                highlighted: _highlighted,
                                onSelect: (b) => setState(() => _highlighted = b),
                                distanceOf: _distanceTo,
                              ),
          ),
        ],
      ),
    );
  }
}

/// Two-way "List / Map" pill switcher in the app bar, matching the visitor
/// directory's toggle but restyled to the agent workspace's [AppColors].
class _ListMapToggle extends StatelessWidget {
  const _ListMapToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(icon: Icons.list_rounded, selected: value == 0, onTap: () => onChanged(0)),
          _ToggleButton(icon: Icons.map_outlined, selected: value == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: selected ? AppColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Icon(icon, size: 17, color: selected ? Colors.white : AppColors.slate),
        ),
      ),
    );
  }
}

/// Map tab: every filtered broker as a pin, positioned by real lat/lng —
/// reuses the same map widgets ([RealBrokerMap] / [BrokerMapBackground] /
/// [BrokerMapPin]) as the visitor-facing broker directory so the map
/// itself behaves identically, just with an agent-appropriate preview
/// card (call/message + "View details" sheet instead of a visitor
/// chat/profile push).
class _AgentMapView extends StatefulWidget {
  const _AgentMapView({
    required this.brokers,
    required this.highlighted,
    required this.onSelect,
    required this.distanceOf,
  });

  final List<Broker> brokers;
  final Broker? highlighted;
  final ValueChanged<Broker> onSelect;
  final double? Function(Broker) distanceOf;

  @override
  State<_AgentMapView> createState() => _AgentMapViewState();
}

class _AgentMapViewState extends State<_AgentMapView> {
  late Future<MapConfig> _mapConfigFuture;

  @override
  void initState() {
    super.initState();
    _mapConfigFuture = MapConfigService().fetchConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.brokers.isEmpty) {
      return const Center(child: Text('No brokers match this search.', style: TextStyle(fontSize: 13.5, color: AppColors.slate)));
    }

    final lats = widget.brokers.map((b) => b.latitude).toList();
    final lngs = widget.brokers.map((b) => b.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<MapConfig>(
            future: _mapConfigFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(color: Color(0xFFE9E4D6), child: Center(child: CircularProgressIndicator()));
              }
              if (kIsWeb || snapshot.hasError || !snapshot.hasData) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        const Positioned.fill(child: BrokerMapBackground()),
                        ...widget.brokers.map((b) {
                          final offset = _project(b.latitude, b.longitude, minLat, maxLat, minLng, maxLng, constraints.biggest);
                          final isSelected = widget.highlighted?.id == b.id;
                          return Positioned(
                            left: offset.dx - 20,
                            top: offset.dy - 44,
                            child: BrokerMapPin(broker: b, selected: isSelected, onTap: () => widget.onSelect(b)),
                          );
                        }),
                      ],
                    );
                  },
                );
              }
              return RealBrokerMap(
                config: snapshot.data!,
                brokers: widget.brokers,
                selected: widget.highlighted,
                onBrokerTapped: widget.onSelect,
              );
            },
          ),
        ),
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
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Text("Tap a pin to see that broker's details.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate, fontSize: 12.5)),
                  )
                : _MapPreviewCard(broker: widget.highlighted!, distanceKm: widget.distanceOf(widget.highlighted!)),
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

/// Compact bottom-sheet-style preview shown under the pinned broker on the
/// map tab. Tapping opens the same [_BrokerDetailSheet] (call/message)
/// used from the list, rather than the visitor-facing profile push.
class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({required this.broker, required this.distanceKm});
  final Broker broker;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final b = broker;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.cloud,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _BrokerDetailSheet(broker: b, distanceKm: distanceKm),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.border, child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      distanceKm != null ? '${b.company} · ${_formatDistance(distanceKm!)}' : '${b.company} · ${b.city}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.pill), border: Border.all(color: selected ? AppColors.ink : AppColors.border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: selected ? Colors.white : AppColors.ink),
                const SizedBox(width: 5),
              ],
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokerCard extends StatelessWidget {
  const _BrokerCard({required this.broker, this.distanceKm, this.onShowOnMap});
  final Broker broker;

  /// Distance from the signed-in agent, when both locations are known —
  /// shown as a pill next to the rating, and drives the row's map icon.
  final double? distanceKm;
  final VoidCallback? onShowOnMap;

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BrokerDetailSheet(broker: broker, distanceKm: distanceKm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = broker;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: AppColors.border, child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(b.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Icon(b.tier.icon, size: 14, color: b.tier.color),
                        const SizedBox(width: 3),
                        Text(b.tier.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: b.tier.color)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distanceKm != null ? '${b.company} · ${_formatDistance(distanceKm!)}' : '${b.company} · ${b.city}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryYellow),
                        const SizedBox(width: 2),
                        Text(b.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b.specialties.map((s) => s.label).join(', '), style: const TextStyle(fontSize: 11.5, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              if (onShowOnMap != null && b.hasPreciseLocation) ...[
                InkWell(
                  onTap: onShowOnMap,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.map_outlined, size: 19, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokerDetailSheet extends StatefulWidget {
  const _BrokerDetailSheet({required this.broker, this.distanceKm});
  final Broker broker;
  final double? distanceKm;

  @override
  State<_BrokerDetailSheet> createState() => _BrokerDetailSheetState();
}

class _BrokerDetailSheetState extends State<_BrokerDetailSheet> {
  final _assetService = AssetService();
  int? _listingsCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _assetService.fetchByBroker(widget.broker.id);
      if (!mounted) return;
      setState(() => _listingsCount = rows.where((a) => a.status == AssetStatus.active).length);
    } on AssetException catch (_) {
      // Leave the stat chip showing "—" rather than a fabricated count.
    }
  }

  Future<void> _call() async {
    if (widget.broker.phone == null) return;
    final uri = Uri(scheme: 'tel', path: widget.broker.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _message() async {
    if (widget.broker.phone == null) return;
    final uri = Uri(scheme: 'sms', path: widget.broker.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.broker;
    final listingsCount = _listingsCount;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Row(
              children: [
                CircleAvatar(radius: 28, backgroundColor: AppColors.border, child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(b.company, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: b.tier.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(b.tier.icon, size: 13, color: b.tier.color),
                    const SizedBox(width: 4),
                    Text(b.tier.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: b.tier.color)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (b.bio != null) ...[
              Text(b.bio!, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5)),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                _StatChip(icon: Icons.star_rounded, label: '${b.rating.toStringAsFixed(1)} rating'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.home_work_outlined, label: listingsCount == null ? '— listings' : '$listingsCount active listings'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.location_on_outlined, label: widget.distanceKm != null ? _formatDistance(widget.distanceKm!) : b.city),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: b.specialties
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.pill), border: Border.all(color: AppColors.border)),
                        child: Text(s.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: b.phone == null ? null : _call, icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(onPressed: b.phone == null ? null : _message, icon: const Icon(Icons.sms_outlined, size: 18), label: const Text('Message')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.sm), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Icon(icon, size: 15, color: AppColors.ink),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.ink), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
