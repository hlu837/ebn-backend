import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/broker.dart';
import '../services/agent_service.dart';
import '../services/gebeta_web_map.dart';
import '../services/map_config_service.dart';
import '../theme/landing_colors.dart';
import 'broker_profile_screen.dart';

/// Map screen showing every broker for a category as a pin.
///
/// Renders a real Gebeta Maps map (tiles + pins) once the app has fetched
/// a map key from the backend (`GET /api/config/map` — see
/// `backend/src/routes/config.js`; the key itself lives only in
/// `backend/.env`, never in this source file). On web this talks to
/// Gebeta's JS SDK directly via [GebetaWebMap] (see that file for why —
/// short version: the gebeta_gl Flutter plugin isn't actually wired up
/// for web despite pub.dev listing it as supported). If the backend
/// hasn't been configured with a key yet, is unreachable, or we're
/// running somewhere [GebetaWebMap] doesn't support, this falls back to
/// the lightweight custom-painted stand-in below so the screen still
/// works for anyone demoing the app without a key set up.
class BrokerMapScreen extends StatefulWidget {
  final AssetCategorySlug category;
  final String categoryLabel;
  final Broker? highlightBroker;

  /// When true, shows every broker in the directory instead of filtering
  /// down to [category] — used by the "Broker List" tile on the landing
  /// page, which isn't tied to a single asset category.
  final bool showAllBrokers;

  const BrokerMapScreen({
    super.key,
    required this.category,
    required this.categoryLabel,
    this.highlightBroker,
    this.showAllBrokers = false,
  });

  @override
  State<BrokerMapScreen> createState() => _BrokerMapScreenState();
}

class _BrokerMapScreenState extends State<BrokerMapScreen> {
  Broker? _selected;

  late Future<MapConfig> _mapConfigFuture;
  final AgentService _agentService = AgentService();

  List<Broker> _brokers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.highlightBroker;
    _mapConfigFuture = MapConfigService().fetchConfig();
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
      final brokers = rows.map(Broker.fromDirectoryJson).where((b) => b.hasPreciseLocation).toList();
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

  @override
  Widget build(BuildContext context) {
    final brokers = _brokers;

    if (_loading) {
      return const Scaffold(
        backgroundColor: LandingColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: LandingColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    _FloatingCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 36, color: LandingColors.muted),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: LandingColors.muted, fontSize: 13.5)),
                        const SizedBox(height: 14),
                        OutlinedButton(onPressed: _loadBrokers, child: const Text('Try again')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (brokers.isEmpty) {
      return Scaffold(
        backgroundColor: LandingColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    _FloatingCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('No brokers with a saved location yet.', style: TextStyle(color: LandingColors.muted)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lats = brokers.map((b) => b.latitude).toList();
    final lngs = brokers.map((b) => b.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: LandingColors.background,
      body: Stack(
        children: [
          // Full-bleed map fills the entire screen behind everything else.
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
                if (snapshot.hasData) {
                  return RealBrokerMap(
                    config: snapshot.data!,
                    brokers: brokers,
                    selected: _selected,
                    onBrokerTapped: (b) => setState(() => _selected = b),
                  );
                }
                return const ColoredBox(
                  color: Color(0xFFE9E4D6),
                  child: Center(child: Text('Map service unavailable.')),
                );
              },
            ),
          ),
          // Small floating back button + title pill, top-left.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _FloatingCircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: LandingColors.card,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Text('${widget.categoryLabel} brokers · map',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LandingColors.foreground),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Small floating broker count / live indicator, top-right.
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: LandingColors.card,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${brokers.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LandingColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Small floating broker preview, docked to the bottom over the map.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _selected == null
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: LandingColors.card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: const Text('Tap a pin to see that broker\'s details.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: LandingColors.muted, fontSize: 12.5)),
                      )
                    : BrokerPreviewCard(broker: _selected!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Projects a lat/lng into pixel coordinates within `size`, padded so
  /// pins never sit flush against the map's edge. Falls back to centering
  /// everything when every broker shares the same coordinate (avoids
  /// divide-by-zero when there's only one pin).
  Offset _project(double lat, double lng, double minLat, double maxLat, double minLng, double maxLng, Size size) {
    const padding = 46.0;
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final nx = lngSpan == 0 ? 0.5 : (lng - minLng) / lngSpan;
    // Latitude increases northward but screen y increases downward.
    final ny = latSpan == 0 ? 0.5 : 1 - (lat - minLat) / latSpan;
    final dx = padding + nx * (size.width - padding * 2);
    final dy = padding + ny * (size.height - padding * 2);
    return Offset(dx, dy);
  }
}

/// Lightweight custom-painted stand-in for a real map tile layer — draws a
/// muted terrain-style background with a road grid so pins have context to
/// sit on, without depending on any map SDK or network tiles.
/// Renders an actual Gebeta Maps map (via [GebetaWebMap], Gebeta's JS SDK
/// embedded through an `HtmlElementView`), fit to the bounds of every
/// broker being shown. Unlike the old gebeta_gl-based version, pins are
/// the existing [BrokerMapPin] Flutter widgets positioned on top of the
/// map using `map.project()`, not native map markers — that keeps their
/// styling, selection animation, and tap handling unchanged while the JS
/// side only has to render tiles and report camera moves.
class RealBrokerMap extends StatefulWidget {
  final MapConfig config;
  final List<Broker> brokers;
  final Broker? selected;
  final ValueChanged<Broker> onBrokerTapped;

  const RealBrokerMap({
    super.key,
    required this.config,
    required this.brokers,
    required this.selected,
    required this.onBrokerTapped,
  });

  @override
  State<RealBrokerMap> createState() => _RealBrokerMapState();
}

class _RealBrokerMapState extends State<RealBrokerMap> {
  late final GebetaWebMap _map;
  StreamSubscription<void>? _styleLoadedSub;
  StreamSubscription<void>? _moveSub;

  /// Becomes true once the style has loaded and `project()` starts
  /// returning real coordinates, so pins don't flash at (0,0) beforehand.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _map = GebetaWebMap.register();
    _styleLoadedSub = _map.onStyleLoaded.listen((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _fitToBrokers();
    });
    _moveSub = _map.onMove.listen((_) {
      // Every pan/zoom moves pins around; project() is recomputed on
      // rebuild, so just trigger one.
      if (mounted) setState(() {});
    });
    // The view factory's div isn't in the DOM yet on this first frame;
    // GebetaWebMap.initialize waits for that internally.
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!kIsWeb) return;
    final first = widget.brokers.isNotEmpty ? widget.brokers.first : null;
    await _map.initialize(
      apiKey: widget.config.apiKey,
      styleUrl: widget.config.styleUrl,
      centerLng: first?.longitude ?? widget.config.defaultLng,
      centerLat: first?.latitude ?? widget.config.defaultLat,
      zoom: 12,
    );
  }

  void _fitToBrokers() {
    if (!kIsWeb) return;
    if (widget.brokers.length <= 1) return; // nothing to "fit" for one pin
    final lats = widget.brokers.map((b) => b.latitude);
    final lngs = widget.brokers.map((b) => b.longitude);
    _map.fitBounds(
      south: lats.reduce((a, b) => a < b ? a : b),
      west: lngs.reduce((a, b) => a < b ? a : b),
      north: lats.reduce((a, b) => a > b ? a : b),
      east: lngs.reduce((a, b) => a > b ? a : b),
      left: 48,
      top: 96,
      right: 48,
      bottom: 160,
    );
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _styleLoadedSub?.cancel();
      _moveSub?.cancel();
      _map.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return FallbackBrokerMap(
        brokers: widget.brokers,
        selected: widget.selected,
        onBrokerTapped: widget.onBrokerTapped,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _map.viewType),
        if (_ready)
          ...widget.brokers.map((b) {
            final point = _map.project(b.longitude, b.latitude);
            if (point == null) return const SizedBox.shrink();
            final isSelected = widget.selected?.id == b.id;
            return Positioned(
              left: point.x - 20,
              top: point.y - 44,
              child: BrokerMapPin(
                broker: b,
                selected: isSelected,
                onTap: () => widget.onBrokerTapped(b),
              ),
            );
          }),
      ],
    );
  }
}

/// Fallback vector map view rendered natively on non-Web platforms (Android / iOS)
/// without relying on dart:html or browser JS interop SDKs.
class FallbackBrokerMap extends StatelessWidget {
  final List<Broker> brokers;
  final Broker? selected;
  final ValueChanged<Broker> onBrokerTapped;

  const FallbackBrokerMap({
    super.key,
    required this.brokers,
    required this.selected,
    required this.onBrokerTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (brokers.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE9E4D6),
        child: Center(child: Text('No broker locations available.')),
      );
    }

    final lats = brokers.map((b) => b.latitude).toList();
    final lngs = brokers.map((b) => b.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          color: const Color(0xFFE9E4D6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: size,
                painter: _MapGridPainter(),
              ),
              for (final b in brokers) ...[
                Builder(
                  builder: (context) {
                    final pos = _project(b.latitude, b.longitude, minLat, maxLat, minLng, maxLng, size);
                    final isSelected = selected?.id == b.id;
                    return Positioned(
                      left: pos.dx - 20,
                      top: pos.dy - 44,
                      child: BrokerMapPin(
                        broker: b,
                        selected: isSelected,
                        onTap: () => onBrokerTapped(b),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Offset _project(
    double lat,
    double lng,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
    Size size,
  ) {
    const paddingHorizontal = 54.0;
    const paddingTop = 90.0;
    const paddingBottom = 170.0;
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final nx = lngSpan == 0 ? 0.5 : (lng - minLng) / lngSpan;
    final ny = latSpan == 0 ? 0.5 : 1 - (lat - minLat) / latSpan;
    final dx = paddingHorizontal + nx * (size.width - paddingHorizontal * 2);
    final dy = paddingTop + ny * (size.height - paddingTop - paddingBottom);
    return Offset(dx, dy);
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = const Color(0xFFFAF7EF)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final paintSecondaryRoad = Paint()
      ..color = const Color(0xFFFFFDFC)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final paintPark = Paint()
      ..color = const Color(0xFFDFE9D6)
      ..style = PaintingStyle.fill;

    // Draw background park area shapes
    final parkPath = Path()
      ..addRRect(RRect.fromLTRBR(size.width * 0.08, size.height * 0.18, size.width * 0.42, size.height * 0.35, const Radius.circular(24)))
      ..addRRect(RRect.fromLTRBR(size.width * 0.58, size.height * 0.52, size.width * 0.9, size.height * 0.75, const Radius.circular(30)));
    canvas.drawPath(parkPath, paintPark);

    // Draw main arterial roads
    final mainRoad1 = Path()
      ..moveTo(0, size.height * 0.32)
      ..cubicTo(size.width * 0.3, size.height * 0.28, size.width * 0.7, size.height * 0.48, size.width, size.height * 0.42);
    canvas.drawPath(mainRoad1, paintRoad);

    final mainRoad2 = Path()
      ..moveTo(size.width * 0.38, 0)
      ..cubicTo(size.width * 0.42, size.height * 0.38, size.width * 0.36, size.height * 0.68, size.width * 0.52, size.height);
    canvas.drawPath(mainRoad2, paintRoad);

    // Secondary grid lines
    for (double y = 90; y < size.height; y += 130) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 25), paintSecondaryRoad);
    }
    for (double x = 70; x < size.width; x += 110) {
      canvas.drawLine(Offset(x, 0), Offset(x - 35, size.height), paintSecondaryRoad);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Small circular icon button that floats on top of the map (used for the
/// back button) instead of the old full-width app-bar-style header.
class _FloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FloatingCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LandingColors.card,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: LandingColors.foreground),
        ),
      ),
    );
  }
}

class BrokerMapPin extends StatelessWidget {
  final Broker broker;
  final bool selected;
  final VoidCallback onTap;
  const BrokerMapPin({super.key, required this.broker, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 36 : 30,
              height: selected ? 36 : 30,
              decoration: BoxDecoration(
                color: selected ? LandingColors.foreground : LandingColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person, size: selected ? 18 : 15, color: selected ? LandingColors.primaryFg : LandingColors.goldFg),
            ),
            CustomPaint(size: const Size(10, 8), painter: BrokerPinTailPainter(color: selected ? LandingColors.foreground : LandingColors.gold)),
          ],
        ),
      ),
    );
  }
}

class BrokerPinTailPainter extends CustomPainter {
  final Color color;
  BrokerPinTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BrokerPinTailPainter oldDelegate) => oldDelegate.color != color;
}

class BrokerPreviewCard extends StatelessWidget {
  final Broker broker;
  const BrokerPreviewCard({super.key, required this.broker});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LandingColors.card,
          border: Border.all(color: LandingColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: LandingColors.gold, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(broker.initials, style: const TextStyle(fontWeight: FontWeight.w700, color: LandingColors.goldFg)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broker.name, style: const TextStyle(fontWeight: FontWeight.w700, color: LandingColors.foreground, fontSize: 14.5)),
                      Text('${broker.company} · ${broker.city}', style: const TextStyle(color: LandingColors.muted, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(broker.tier.icon, size: 16, color: broker.tier.color),
                const SizedBox(width: 3),
                Text(broker.tier.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: broker.tier.color)),
              ],
            ),
            if (broker.addressLine != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: LandingColors.muted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(broker.addressLine!, style: const TextStyle(fontSize: 12.5, color: LandingColors.muted))),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BrokerProfileScreen(broker: broker))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: LandingColors.foreground, borderRadius: BorderRadius.circular(999)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.primaryFg)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: LandingColors.primaryFg),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
