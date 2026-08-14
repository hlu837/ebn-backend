import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/chat_message.dart' as api;
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'broker_chat_screen.dart';

/// Real "Messages" inbox — backed by `GET /api/chat/threads`, which
/// already returns each thread's other party, the listing it's about,
/// the last message, and an unread count, so this screen just renders
/// that directly rather than re-deriving anything client-side.
///
/// Role-agnostic: the same screen serves both the Agent workspace (as a
/// persistent bottom-nav tab, [showBackButton] = false) and the Visitor
/// side (pushed as its own route from the bottom nav, [showBackButton] =
/// true) — the backend already scopes `listThreads` to whichever side of
/// each thread the caller is on, so no role-specific logic is needed here.
///
/// No socket client is wired up yet (see `broker_chat_screen.dart`), so
/// this polls on the same 4–5s interval used elsewhere in the app.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key, required this.user, this.onUnreadChanged, this.showBackButton = true});

  final AppUser user;

  /// Called after every successful load with the sum of unread counts
  /// across all threads, so a parent shell (e.g. the bottom nav) can show
  /// a badge without this screen needing to know about it directly.
  final ValueChanged<int>? onUnreadChanged;

  /// False when this screen lives inline in a bottom-nav tab (there's
  /// nothing to navigate back to); true when it's pushed as its own route.
  final bool showBackButton;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _service = ChatService();
  List<api.ChatThread> _threads = const [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  String get _token => widget.user.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final threads = await _service.listThreads(token: _token);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
        _error = null;
      });
      widget.onUnreadChanged?.call(threads.fold<int>(0, (sum, t) => sum + t.unreadCount));
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // A silent background refresh failing (e.g. a dropped poll tick)
        // shouldn't blow away an already-populated list with an error
        // screen — just try again next tick.
        if (!silent) _error = e.message;
      });
    }
  }

  Future<void> _openThread(api.ChatThread thread) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BrokerChatScreen.fromThread(thread: thread, currentUser: widget.user),
    ));
    if (!mounted) return;
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        elevation: 0,
        foregroundColor: AppColors.ink,
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('Messages', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
            : _error != null
                ? _ErrorState(message: _error!, onRetry: () => _load())
                : _threads.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryYellow,
                        onRefresh: () => _load(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: _threads.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border, indent: 78),
                          itemBuilder: (context, i) {
                            final thread = _threads[i];
                            return _ThreadTile(thread: thread, onTap: () => _openThread(thread));
                          },
                        ),
                      ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final api.ChatThread thread;
  final VoidCallback onTap;
  const _ThreadTile({required this.thread, required this.onTap});

  String get _name => thread.otherParty?.fullName.trim().isNotEmpty == true ? thread.otherParty!.fullName : 'Customer';

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final unread = thread.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.ink,
              child: Text(_initials, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _name,
                          style: TextStyle(fontSize: 14.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w700, color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.lastMessageAt != null)
                        Text(
                          _relativeTime(thread.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: unread ? AppColors.primaryYellow : AppColors.slate,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (thread.asset != null)
                    Text(
                      'About: ${thread.asset!.title}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessageBody?.trim().isNotEmpty == true ? thread.lastMessageBody! : 'No messages yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: unread ? AppColors.ink : AppColors.slate,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            thread.unreadCount > 9 ? '9+' : '${thread.unreadCount}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 44, color: AppColors.slate),
            SizedBox(height: 14),
            Text('No conversations yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            SizedBox(height: 6),
            Text(
              "When a customer messages you about one of your listings, it'll show up here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontSize: 14)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Small self-contained "time ago" formatter — no `intl` dependency in
/// this project, and the format needed here (e.g. "2h", "3d") is simple
/// enough not to warrant adding one.
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w';
  return '${dt.month}/${dt.day}/${dt.year % 100}';
}
