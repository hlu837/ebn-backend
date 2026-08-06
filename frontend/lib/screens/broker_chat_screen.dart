import 'dart:async';

import 'package:flutter/material.dart';
import '../models/broker.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/chat_message.dart' as api;
import '../services/chat_service.dart';
import '../theme/landing_colors.dart';

/// Real two-way chat between the current user and a broker, scoped to one
/// specific listing — backed by `/api/chat/*` (see `chat_service.dart`).
///
/// There's no socket client wired up in this app yet, so new messages are
/// picked up by polling on an interval, the same pattern used elsewhere
/// (see `loop_controller.dart`).
///
/// Note: [broker.id] must be a real signed-up agent's user id (i.e. the
/// asset's `broker_id` needs to resolve to an actual `users` row with
/// role `agent`). Legacy/seeded listings still using mock ids like `b1`
/// will fail to open a thread — see the error surfaced in [initState].
class BrokerChatScreen extends StatefulWidget {
  /// The two ways into this screen:
  ///  - [broker] + [asset]: from a listing ("Chat about this listing") —
  ///    the full models are already in hand, so the header can show them
  ///    immediately while the thread opens in the background.
  ///  - [initialThread]: from the inbox ([ChatInboxScreen]) — the
  ///    thread already exists server-side, so there's no need to re-derive
  ///    the agent from an asset; the header falls back to the thread's
  ///    lighter-weight `otherParty`/`asset` summary instead.
  final Broker? broker;
  final Asset? asset;
  final api.ChatThread? initialThread;
  final AppUser currentUser;

  const BrokerChatScreen({
    super.key,
    required Broker this.broker,
    required Asset this.asset,
    required this.currentUser,
  }) : initialThread = null;

  const BrokerChatScreen.fromThread({
    super.key,
    required api.ChatThread thread,
    required this.currentUser,
  })  : initialThread = thread,
        broker = null,
        asset = null;

  @override
  State<BrokerChatScreen> createState() => _BrokerChatScreenState();
}

class _BrokerChatScreenState extends State<BrokerChatScreen> {
  final _service = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <api.ChatMessage>[];

  api.ChatThread? _thread;
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _token => widget.currentUser.token ?? '';

  /// Display name for the header — the full [Broker] when we have one,
  /// otherwise the thread's lighter-weight `otherParty` summary.
  String get _headerName => widget.broker?.name ?? _thread?.otherParty?.fullName ?? 'Agent';

  String get _headerInitials {
    if (widget.broker != null) return widget.broker!.initials;
    final parts = _headerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String get _assetTitle => widget.asset?.title ?? _thread?.asset?.title ?? 'Listing';
  String? get _assetImageUrl => widget.asset?.imageUrl ?? _thread?.asset?.imageUrl;
  String? get _assetPriceText => widget.asset?.formattedPrice;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final thread = widget.initialThread ?? await _service.openThreadForAsset(token: _token, assetId: widget.asset!.id);
      final history = await _service.messagesForThread(token: _token, threadId: thread.id);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _messages.addAll(history);
        _loading = false;
      });
      _scrollToBottom();
      unawaited(_service.markRead(token: _token, threadId: thread.id));
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _poll() async {
    final thread = _thread;
    if (thread == null || _sending) return;
    try {
      final latest = await _service.messagesForThread(token: _token, threadId: thread.id);
      if (!mounted) return;
      if (latest.length != _messages.length) {
        setState(() {
          _messages
            ..clear()
            ..addAll(latest);
        });
        _scrollToBottom();
        unawaited(_service.markRead(token: _token, threadId: thread.id));
      }
    } on ChatException {
      // Transient network hiccup — the next poll will retry. No need to
      // surface every dropped tick as an error to the user.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final thread = _thread;
    final text = _controller.text.trim();
    if (thread == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      final message = await _service.sendMessage(token: _token, threadId: thread.id, body: text);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _sending = false;
      });
      _scrollToBottom();
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _controller.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingColors.background,
      appBar: AppBar(
        backgroundColor: LandingColors.foreground,
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: LandingColors.gold,
              child: Text(_headerInitials,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: LandingColors.goldFg, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_headerName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('About: $_assetTitle',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!)
                : Column(
                    children: [
                      _ListingBanner(title: _assetTitle, imageUrl: _assetImageUrl, priceText: _assetPriceText),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];
                            return _Bubble(message: m, mine: m.senderId == widget.currentUser.id);
                          },
                        ),
                      ),
                      _Composer(controller: _controller, onSend: _send, sending: _sending),
                    ],
                  ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: LandingColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LandingColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ListingBanner extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? priceText;
  const _ListingBanner({required this.title, this.imageUrl, this.priceText});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LandingColors.card,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: LandingColors.border))
                  : Container(color: LandingColors.border),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.foreground),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (priceText != null) Text(priceText!, style: const TextStyle(fontSize: 12, color: LandingColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final api.ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? LandingColors.foreground : LandingColors.card;
    final fg = mine ? LandingColors.primaryFg : LandingColors.foreground;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: bg,
          border: mine ? null : Border.all(color: LandingColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(message.body, style: TextStyle(fontSize: 14, color: fg, height: 1.3)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  const _Composer({required this.controller, required this.onSend, required this.sending});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message about this listing...',
                hintStyle: const TextStyle(color: LandingColors.muted),
                filled: true,
                fillColor: LandingColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: LandingColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: LandingColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: LandingColors.gold, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: LandingColors.foreground,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: LandingColors.primaryFg),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: LandingColors.primaryFg, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
