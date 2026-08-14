import 'package:flutter/foundation.dart';

import '../models/auth_response.dart';
import '../services/favorite_service.dart';

/// Tracks which asset IDs the current visitor has favorited, shared above
/// the Navigator (see `main.dart`) so a heart tapped on the Top picks grid
/// is reflected instantly on the Favorites / Saved Listings page and vice
/// versa.
///
/// Backed by the real `/api/favorites/*` endpoints via [FavoriteService].
/// [_favoriteAssetIds] is still an in-memory cache — that's what makes
/// every heart icon in the app re-render instantly — but it's now hydrated
/// from, and kept in sync with, Postgres instead of being the source of
/// truth itself. Call [attachUser] once the signed-in visitor's session is
/// known (e.g. the home shell's `initState`) to load their saved listings;
/// a guest session (no token) behaves exactly like the old mock — local
/// only, cleared on app restart.
class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoriteService? service}) : _service = service ?? FavoriteService();

  final FavoriteService _service;

  final Set<String> _favoriteAssetIds = {};
  String? _userId;
  String? _token;
  bool _loadedForCurrentUser = false;

  bool isFavorite(String assetId) => _favoriteAssetIds.contains(assetId);

  List<String> get favoriteAssetIds => _favoriteAssetIds.toList(growable: false);

  /// Hydrates the saved-listings cache for [user] from the backend. Safe
  /// to call repeatedly (e.g. from every screen's `initState`) — it's a
  /// no-op once already loaded for this same account. A guest [user]
  /// (no token) is left as local-only, matching the old mock behavior.
  Future<void> attachUser(AppUser user) async {
    final token = user.token;
    if (token == null) return;
    if (_userId == user.id && _loadedForCurrentUser) return;

    if (_userId != user.id) {
      // Switched accounts (e.g. signed out and into a different one) —
      // don't leak the previous user's saved listings while we fetch.
      _favoriteAssetIds.clear();
    }
    _userId = user.id;
    _token = token;

    try {
      final ids = await _service.fetchFavoriteIds(token);
      _favoriteAssetIds
        ..clear()
        ..addAll(ids);
      _loadedForCurrentUser = true;
      notifyListeners();
    } on FavoriteException {
      // Transient network hiccup — leave whatever's already cached in
      // place; the next attachUser call (e.g. reopening Favorites) retries.
    }
  }

  /// Resets to a clean, logged-out state. Call this on sign-out so the
  /// next session (guest or a different account) doesn't start out
  /// showing someone else's saved listings.
  void clearUser() {
    _userId = null;
    _token = null;
    _loadedForCurrentUser = false;
    _favoriteAssetIds.clear();
    notifyListeners();
  }

  /// Optimistically flips [assetId]'s saved state immediately — so the
  /// heart icon responds instantly — then syncs the change to the
  /// backend. If a signed-in session is attached and the sync fails, the
  /// local flip is rolled back so the UI never lies about what's actually
  /// saved server-side. With no session attached (guest), this behaves
  /// like the old in-memory-only mock.
  Future<void> toggle(String assetId) async {
    final wasFavorite = _favoriteAssetIds.contains(assetId);
    if (wasFavorite) {
      _favoriteAssetIds.remove(assetId);
    } else {
      _favoriteAssetIds.add(assetId);
    }
    notifyListeners();

    final token = _token;
    if (token == null) return;

    try {
      if (wasFavorite) {
        await _service.removeFavorite(token, assetId);
      } else {
        await _service.addFavorite(token, assetId);
      }
    } on FavoriteException {
      // Revert — the backend didn't accept the change.
      if (wasFavorite) {
        _favoriteAssetIds.add(assetId);
      } else {
        _favoriteAssetIds.remove(assetId);
      }
      notifyListeners();
    }
  }
}
