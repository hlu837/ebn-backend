// Thin JS-interop wrapper around Gebeta Maps' official web SDK, loaded in
// web/index.html via:
//   <link rel="stylesheet" href="https://tiles.gebeta.app/static/gebeta-maps-lib.css" />
//   <script type="module" src="https://tiles.gebeta.app/static/gebeta-maps.umd.js"></script>

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

class GebetaWebMap {
  GebetaWebMap._(this.viewType, this._container);

  static int _counter = 0;

  final String viewType;
  final html.DivElement _container;

  /// The underlying JS `Map` instance returned by `GebetaMaps#init()`.
  JSObject? _mapJs;
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

    final gebetaMapsCtor = globalContext.getProperty('GebetaMaps'.toJS);
    if (gebetaMapsCtor == null) {
      throw StateError(
        'window.GebetaMaps is undefined — check that web/index.html loads '
        'https://tiles.gebeta.app/static/gebeta-maps.umd.js before this runs.',
      );
    }

    final gebetaMaps = (gebetaMapsCtor as JSFunction).callAsConstructor(
      {'apiKey': apiKey}.jsify(),
    ) as JSObject;

    final map = gebetaMaps.callMethod(
      'init'.toJS,
      {
        'container': _container.id,
        'center': [centerLng, centerLat],
        'zoom': zoom,
        'style': styleUrl,
      }.jsify(),
    ) as JSObject;
    _mapJs = map;

    map.callMethod(
      'on'.toJS,
      'load'.toJS,
      (() {
        if (!_disposed) _styleLoadedController.add(null);
      }).toJS,
    );
    map.callMethod(
      'on'.toJS,
      'move'.toJS,
      (() {
        if (!_disposed) _moveController.add(null);
      }).toJS,
    );

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
    map.callMethod('resize'.toJS);
  }

  /// Projects a lat/lng to a pixel offset within the map container,
  /// matching MapLibre GL JS's `Map#project`. Returns null until the map
  /// has been initialized.
  ({double x, double y})? project(double lng, double lat) {
    final map = _mapJs;
    if (map == null) return null;
    final point = map.callMethod(
      'project'.toJS,
      [lng, lat].jsify(),
    ) as JSObject;
    final x = (point.getProperty('x'.toJS) as JSNumber).toDartDouble;
    final y = (point.getProperty('y'.toJS) as JSNumber).toDartDouble;
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
    map.callMethod(
      'fitBounds'.toJS,
      [
        [west, south],
        [east, north],
      ].jsify(),
      {
        'padding': {'left': left, 'top': top, 'right': right, 'bottom': bottom},
        'duration': 600,
      }.jsify(),
    );
  }

  void dispose() {
    _disposed = true;
    _readyPoll?.cancel();
    _styleLoadedController.close();
    _moveController.close();
    final map = _mapJs;
    if (map != null) {
      map.callMethod('remove'.toJS);
    }
    _mapJs = null;
  }
}
