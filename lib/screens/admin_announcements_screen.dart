import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

const List<String> _kCategories = ['General', 'Payout', 'Update'];

/// Admin-only screen: compose a new announcement and manage (delete)
/// existing ones. Investor side reads the same `/api/announcements` feed
/// read-only — see AnnouncementService.list().
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final AnnouncementService _service = AnnouncementService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _category = _kCategories.first;
  bool _isPinned = false;
  bool _submitting = false;

  List<Announcement> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await _service.list();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      AppToast.showError(context, 'Title and content are required.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.create(
        token: widget.token,
        title: title,
        content: content,
        category: _category,
        isPinned: _isPinned,
      );
      _titleController.clear();
      _contentController.clear();
      if (!mounted) return;
      setState(() {
        _category = _kCategories.first;
        _isPinned = false;
        _submitting = false;
      });
      await _load();
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _delete(Announcement post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"${post.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(token: widget.token, id: post.id);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == post.id));
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
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
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ComposeCard(
              titleController: _titleController,
              contentController: _contentController,
              category: _category,
              isPinned: _isPinned,
              submitting: _submitting,
              onCategoryChanged: (value) => setState(() => _category = value),
              onPinnedChanged: (value) => setState(() => _isPinned = value),
              onSubmit: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Posted', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: Text('No announcements yet.', style: TextStyle(color: AppColors.slate))),
              )
            else
              ..._posts.map((post) => _AnnouncementCard(post: post, onDelete: () => _delete(post))),
          ],
        ),
      ),
    );
  }
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.titleController,
    required this.contentController,
    required this.category,
    required this.isPinned,
    required this.submitting,
    required this.onCategoryChanged,
    required this.onPinnedChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final String category;
  final bool isPinned;
  final bool submitting;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onPinnedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Announcement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: contentController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _kCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: isPinned, onChanged: (value) => onPinnedChanged(value ?? false)),
                  const Text('Pinned', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: submitting ? 'Posting…' : 'Post Announcement',
            onPressed: submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.post, required this.onDelete});

  final Announcement post;
  final VoidCallback onDelete;

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
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          Text(
            '${post.category} · ${post.createdAt.toLocal()}'.split('.').first,
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
          ),
          const SizedBox(height: 6),
          Text(post.content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
