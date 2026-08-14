// Used whenever this app is compiled for a target other than web (where
// dart:html isn't available). Every call site in broker_map_screen.dart
// is already guarded behind `kIsWeb`, so nothing here should ever
// actually execute — this only exists so the app keeps compiling if a
// mobile target is ever added back.
class GebetaWebMap {
  GebetaWebMap._();

  factory GebetaWebMap.register() => GebetaWebMap._();

  String get viewType => throw UnsupportedError(
        'GebetaWebMap only works on Flutter Web (needs dart:html/dart:js_util).',
      );

  Stream<void> get onStyleLoaded => throw UnsupportedError(
        'GebetaWebMap only works on Flutter Web (needs dart:html/dart:js_util).',
      );

  Stream<void> get onMove => throw UnsupportedError(
        'GebetaWebMap only works on Flutter Web (needs dart:html/dart:js_util).',
      );

  Future<void> initialize({
    required String apiKey,
    required String styleUrl,
    required double centerLng,
    required double centerLat,
    required double zoom,
  }) =>
      throw UnsupportedError(
        'GebetaWebMap only works on Flutter Web (needs dart:html/dart:js_util).',
      );

  void resize() {}

  ({double x, double y})? project(double lng, double lat) => null;

  void fitBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {}

  void dispose() {}
}
