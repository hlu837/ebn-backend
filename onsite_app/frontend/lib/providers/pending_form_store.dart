import 'package:flutter/foundation.dart';
import '../models/asset.dart';

/// Which form the guest was filling when they hit "submit" as a guest.
enum PendingFormType { order, sell }

/// Holds form data captured by a guest user so it can be restored after
/// sign-up or login. Lives at the app root via [MultiProvider] in main.dart,
/// so it survives navigation between form screens and auth screens.
///
/// Usage:
///   1. Form screen detects `widget.user.id == 'guest'` on submit.
///   2. Calls [saveOrderForm] / [saveSellForm] with all field values.
///   3. Navigates to auth (RoleSelectScreen → SignUpScreen / LoginScreen).
///   4. On auth success, signup/login checks [hasPending].
///   5. If true, navigates to the form screen with `resumeAfterAuth: true`.
///   6. Form's `initState` restores state from [pendingData], then auto-submits.
///   7. After successful submission, form calls [clear].
class PendingFormStore extends ChangeNotifier {
  PendingFormType? _type;
  AssetCategorySlug? _category;
  Map<String, dynamic> _data = {};

  PendingFormType? get pendingFormType => _type;
  AssetCategorySlug? get pendingCategory => _category;
  Map<String, dynamic> get pendingData => _data;
  bool get hasPending => _type != null;

  /// Save an order form's state for later resumption.
  void saveOrderForm({
    required AssetCategorySlug category,
    required Map<String, dynamic> data,
  }) {
    _type = PendingFormType.order;
    _category = category;
    _data = Map<String, dynamic>.from(data);
    notifyListeners();
  }

  /// Save a sell form's state for later resumption.
  void saveSellForm({
    required AssetCategorySlug category,
    required Map<String, dynamic> data,
  }) {
    _type = PendingFormType.sell;
    _category = category;
    _data = Map<String, dynamic>.from(data);
    notifyListeners();
  }

  /// Wipe the pending data after a successful submission or if the user
  /// explicitly cancels.
  void clear() {
    _type = null;
    _category = null;
    _data = {};
    notifyListeners();
  }
}
