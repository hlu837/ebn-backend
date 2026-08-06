import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../theme/app_theme.dart';

/// Investor-facing read of the same `/api/announcements` feed the admin
/// side writes to (see AdminAnnouncementsScreen). Read-only: no compose or
/// delete controls, just the pinned-first, newest-first list.
class InvestorAnnouncementsScreen extends StatefulWidget {
  const InvestorAnnouncementsScreen({super.key});

  @override
  State<InvestorAnnouncementsScreen> createState() => _InvestorAnnouncementsScreenState();
}

class _InvestorAnnouncementsScreenState extends State<InvestorAnnouncementsScreen> {
  final AnnouncementService _service = AnnouncementService();

  List<Announcement> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.list();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('News & Announcements'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _posts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: Text('No announcements yet.', style: TextStyle(color: AppColors.slate)),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: _posts.map((post) => _AnnouncementCard(post: post)).toList(),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: AppSpacing.lg),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.slate),
                const SizedBox(height: AppSpacing.sm),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.post});

  final Announcement post;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.isPinned) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primaryYellow),
              ),
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              _CategoryChip(category: post.category),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            post.createdAt.toLocal().toString().split('.').first,
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
          ),
          const SizedBox(height: 6),
          Text(post.content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        category,
        style: const TextStyle(color: AppColors.primaryYellow, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}
