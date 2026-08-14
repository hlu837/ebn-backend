import 'dart:async';

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

const _kAccentRed = Color(0xFFFF2636);

String _timeLabel(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

/// Shared notifications inbox for any signed-in role (agent, customer,
/// etc) — backed by the generic `/api/notifications` endpoints. Polls
/// every [_pollInterval] the same way the rest of the app's "live-ish"
/// screens do (see loop_controller.dart) since there's no socket client
/// wired up yet.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.token, this.onUnreadCountChanged});

  final String token;
  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Duration _pollInterval = Duration(seconds: 15);

  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Fetches the feed. [silent] is used by the background poll so it
  /// doesn't flash the loading spinner or clobber a request that's still
  /// in flight from a manual pull-to-refresh.
  Future<void> _load({bool silent = false}) async {
    if (widget.token.isEmpty) {
      if (silent) return;
      setState(() {
        _isLoading = false;
        _error = "You're not signed in.";
      });
      return;
    }
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final notifications = await _service.getNotifications(widget.token);
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _error = null;
      });
      _reportUnreadCount();
    } on NotificationException catch (e) {
      if (!mounted) return;
      // A silent background poll failing (e.g. a dropped connection)
      // shouldn't replace an already-loaded list with an error screen.
      if (silent && _notifications.isNotEmpty) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent && _notifications.isNotEmpty) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't load notifications.";
      });
    }
  }

  void _reportUnreadCount() {
    final unread = _notifications.where((n) => !n.isRead).length;
    widget.onUnreadCountChanged?.call(unread);
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    setState(() {
      _notifications = [
        for (final existing in _notifications)
          if (existing.id == n.id) existing.copyWith(isRead: true) else existing,
      ];
    });
    _reportUnreadCount();
    try {
      await _service.markRead(widget.token, n.id);
    } catch (_) {
      // Local state already reflects the intent; reconciles on next load.
    }
  }

  Future<void> _markAllRead() async {
    final hadUnread = _notifications.any((n) => !n.isRead);
    if (!hadUnread) return;
    setState(() {
      _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
    });
    _reportUnreadCount();
    try {
      await _service.markAllRead(widget.token);
    } catch (_) {
      // Same as above.
    }
  }

  IconData _iconFor(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.newDispatch:
        return Icons.local_shipping_outlined;
      case AppNotificationKind.chatMessage:
        return Icons.chat_bubble_outline_rounded;
      case AppNotificationKind.payout:
        return Icons.account_balance_wallet_outlined;
      case AppNotificationKind.system:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kAccentRed));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_notifications.isEmpty) {
      return const _EmptyNotifications();
    }
    return RefreshIndicator(
      color: _kAccentRed,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final n = _notifications[i];
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => _markRead(n),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: n.isRead ? AppColors.card : _kAccentRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: n.isRead ? AppColors.border : _kAccentRed.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: _kAccentRed.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(_iconFor(n.kind), size: 18, color: _kAccentRed),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                            ),
                            if (!n.isRead)
                              Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6), decoration: const BoxDecoration(color: _kAccentRed, shape: BoxShape.circle)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(n.body, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate, height: 1.35)),
                        const SizedBox(height: 6),
                        Text(_timeLabel(n.createdAt), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.slate),
            SizedBox(height: AppSpacing.md),
            Text("You're all caught up.", style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('Try again', style: TextStyle(color: _kAccentRed, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}
