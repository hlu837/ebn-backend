// gebeta_gl (the pub.dev Flutter plugin) lists "web" as a supported
// platform, but the published package's own dependency graph only pulls
// in `gebeta_gl_platform_interface` — there's no `gebeta_gl_web`
// implementation wired into the version this app depends on, which is
// why it never registered as a web plugin (see
// frontend/.flutter-plugins-dependencies: nothing under "web" for
// gebeta_gl). Gebeta does publish a real web SDK, just not through this
// Flutter package — see https://tiles.gebeta.app/static/gebeta-maps.umd.js,
// loaded in web/index.html. This file talks to that SDK directly via
// JS interop instead of going through gebeta_gl.
//
// The actual implementation needs dart:html + dart:js_util, which only
// resolve when compiling for web. Everything that touches this class is
// already guarded by `kIsWeb` in broker_map_screen.dart, but we still
// conditionally export a stub for non-web targets so the app keeps
// compiling/analyzing cleanly if an android/ or ios/ folder ever comes
// back.
export 'gebeta_web_map/gebeta_web_map_stub.dart'
    if (dart.library.html) 'gebeta_web_map/gebeta_web_map_web.dart';
