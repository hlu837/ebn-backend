// Thin JS-interop wrapper around Gebeta Maps' official web SDK, loaded in
// web/index.html via:
//   <link rel="stylesheet" href="https://tiles.gebeta.app/static/gebeta-maps-lib.css" />
//   <script type="module" src="https://tiles.gebeta.app/static/gebeta-maps.umd.js"></script>
//
// That SDK is built on MapLibre GL JS (same engine gebeta_gl wraps
// natively on Android/iOS), so the underlying `map` object exposes the
// familiar MapLibre API: `.on(event, cb)`, `.project(lngLat)`,
// `.fitBounds(bounds, options)`, `.resize()`, `.remove()`. See:
// https://gebeta.app/blog/google-to-gebeta-migration
//
// We deliberately do NOT use the SDK's own marker API. Instead we read
// pixel positions back out via `map.project()` and let Flutter draw the
// existing `BrokerMapPin` widgets on top of the HtmlElementView. That
// keeps broker-pin styling, selection state, and tap handling exactly as
// they were, all in Dart, with the JS side doing nothing but rendering
// tiles and reporting camera moves.
//
// dart:html and dart:js_util are both fully functional today (only
// soft-deprecated in favor of package:web/dart:js_interop) and are the
// most broadly-compatible way to write this without a local toolchain to
// verify against — swap to dart:js_interop later if you want the newer
// typed interop style.

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

class GebetaWebMap {
  GebetaWebMap._(this.viewType, this._container);

  static int _counter = 0;

  final String viewType;
  final html.DivElement _container;

  /// The underlying JS `Map` instance returned by `GebetaMaps#init()`.
  Object? _mapJs;
  Timer? _readyPoll;
  bool _disposed = false;

  final _styleLoadedController = StreamController<void>.broadcast();
  final _moveController = StreamController<void>.broadcast();

  /// Fires once the map's style has finished loading — equivalent to
  /// gebeta_gl's `onStyleLoadedCallback`.
  Stream<void> get onStyleLoaded => _styleLoadedController.stream;

  /// Fires on every camera pan/zoom so pin overlays can reproject.
  Stream<void> get onMove => _moveController.stream;

  /// Registers a fresh platform view and returns a [GebetaWebMap] handle
  /// for it. Call [initialize] once the matching `HtmlElementView` has
  /// been built.
  factory GebetaWebMap.register() {
    final id = _counter++;
    final container = html.DivElement()
      ..id = 'gebeta-map-container-$id'
      ..style.width = '100%'
      ..style.height = '100%';
    final viewType = 'gebeta-map-view-$id';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int _) => container,
    );
    return GebetaWebMap._(viewType, container);
  }

  /// Waits for the container div to actually land in the DOM (Flutter
  /// inserts it asynchronously after the widget builds), then boots the
  /// Gebeta Maps JS SDK inside it.
  Future<void> initialize({
    required String apiKey,
    required String styleUrl,
    required double centerLng,
    required double centerLat,
    required double zoom,
  }) async {
    await _waitUntilConnected();
    if (_disposed) return;

    final gebetaMapsCtor = js_util.getProperty(html.window, 'GebetaMaps');
    if (gebetaMapsCtor == null) {
      throw StateError(
        'window.GebetaMaps is undefined — check that web/index.html loads '
        'https://tiles.gebeta.app/static/gebeta-maps.umd.js before this runs.',
      );
    }

    final gebetaMaps = js_util.callConstructor(gebetaMapsCtor, [
      js_util.jsify({'apiKey': apiKey}),
    ]);

    final map = js_util.callMethod(gebetaMaps, 'init', [
      js_util.jsify({
        'container': _container.id,
        'center': [centerLng, centerLat],
        'zoom': zoom,
        'style': styleUrl,
      }),
    ]);
    _mapJs = map;

    js_util.callMethod(map, 'on', [
      'load',
      js.allowInterop(() {
        if (!_disposed) _styleLoadedController.add(null);
      }),
    ]);
    js_util.callMethod(map, 'on', [
      'move',
      js.allowInterop(() {
        if (!_disposed) _moveController.add(null);
      }),
    ]);

    // The container's true layout size is only settled once Flutter has
    // positioned the HtmlElementView; nudge MapLibre to re-measure so
    // tiles aren't clipped to whatever size existed at construction time.
    Future.delayed(const Duration(milliseconds: 50), resize);
  }

  Future<void> _waitUntilConnected() async {
    if (_container.isConnected == true) return;
    final completer = Completer<void>();
    _readyPoll = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_container.isConnected == true || _disposed) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    // Don't hang forever if the view never gets mounted.
    unawaited(Future.delayed(const Duration(seconds: 5), () {
      _readyPoll?.cancel();
      if (!completer.isCompleted) completer.complete();
    }));
    await completer.future;
  }

  void resize() {
    final map = _mapJs;
    if (map == null) return;
    js_util.callMethod(map, 'resize', []);
  }

  /// Projects a lat/lng to a pixel offset within the map container,
  /// matching MapLibre GL JS's `Map#project`. Returns null until the map
  /// has been initialized.
  ({double x, double y})? project(double lng, double lat) {
    final map = _mapJs;
    if (map == null) return null;
    final point = js_util.callMethod(map, 'project', [
      js_util.jsify([lng, lat]),
    ]);
    final x = (js_util.getProperty(point, 'x') as num).toDouble();
    final y = (js_util.getProperty(point, 'y') as num).toDouble();
    return (x: x, y: y);
  }

  /// Fits the camera to a lat/lng bounding box, matching gebeta_gl's
  /// `CameraUpdate.newLatLngBounds`.
  void fitBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final map = _mapJs;
    if (map == null) return;
    js_util.callMethod(map, 'fitBounds', [
      js_util.jsify([
        [west, south],
        [east, north],
      ]),
      js_util.jsify({
        'padding': {'left': left, 'top': top, 'right': right, 'bottom': bottom},
        'duration': 600,
      }),
    ]);
  }

  void dispose() {
    _disposed = true;
    _readyPoll?.cancel();
    _styleLoadedController.close();
    _moveController.close();
    final map = _mapJs;
    if (map != null) {
      js_util.callMethod(map, 'remove', []);
    }
    _mapJs = null;
  }
}
