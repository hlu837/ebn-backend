import 'package:flutter/material.dart';

import '../models/admin_settings_models.dart';
import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin > Settings > App Content. Edit the static customer-facing pages
/// (FAQ, About Us, Platform Features) without shipping a new app build.
class AdminAppContentScreen extends StatefulWidget {
  const AdminAppContentScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminAppContentScreen> createState() => _AdminAppContentScreenState();
}

class _AdminAppContentScreenState extends State<AdminAppContentScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminSettingsService _service = AdminSettingsService();

  List<AdminFaqEntry> _faq = const [];
  List<AdminContentPage> _pages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.fetchFaq(token: widget.token),
        _service.fetchContentPages(token: widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _faq = results[0] as List<AdminFaqEntry>;
        _pages = results[1] as List<AdminContentPage>;
        _loading = false;
      });
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  AdminContentPage? _page(String key) {
    for (final p in _pages) {
      if (p.pageKey == key) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('App Content'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          indicatorColor: AppColors.primaryYellow,
          tabs: const [Tab(text: 'FAQ'), Tab(text: 'About Us'), Tab(text: 'Features')],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _FaqTab(token: widget.token, service: _service, entries: _faq, onChanged: _load),
                  _PageTab(
                    key: const ValueKey('about_us'),
                    token: widget.token,
                    service: _service,
                    pageKey: 'about_us',
                    page: _page('about_us'),
                    onSaved: _load,
                  ),
                  _PageTab(
                    key: const ValueKey('features'),
                    token: widget.token,
                    service: _service,
                    pageKey: 'features',
                    page: _page('features'),
                    onSaved: _load,
                  ),
                ],
              ),
      ),
    );
  }
}

class _FaqTab extends StatelessWidget {
  const _FaqTab({required this.token, required this.service, required this.entries, required this.onChanged});

  final String token;
  final AdminSettingsService service;
  final List<AdminFaqEntry> entries;
  final VoidCallback onChanged;

  Future<void> _openEditor(BuildContext context, {AdminFaqEntry? existing}) async {
    final questionController = TextEditingController(text: existing?.question ?? '');
    final answerController = TextEditingController(text: existing?.answer ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add FAQ Entry' : 'Edit FAQ Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: answerController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Answer', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;

    final question = questionController.text.trim();
    final answer = answerController.text.trim();
    if (question.isEmpty || answer.isEmpty) {
      if (context.mounted) AppToast.showError(context, 'Question and answer are both required.');
      return;
    }

    try {
      if (existing == null) {
        await service.createFaq(question: question, answer: answer, token: token);
      } else {
        await service.updateFaq(existing.id, question: question, answer: answer, token: token);
      }
      onChanged();
    } on AdminSettingsServiceException catch (e) {
      if (context.mounted) AppToast.showError(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, AdminFaqEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete FAQ entry?'),
        content: Text('"${entry.question}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.removeFaq(entry.id, token: token);
      onChanged();
    } on AdminSettingsServiceException catch (e) {
      if (context.mounted) AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
          children: [
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: Text('No FAQ entries yet.', style: TextStyle(color: AppColors.slate))),
              )
            else
              ...entries.map(
                (entry) => Container(
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
                          Expanded(
                            child: Text(entry.question, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _openEditor(context, existing: entry),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                            onPressed: () => _delete(context, entry),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(entry.answer, style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: FloatingActionButton.extended(
            heroTag: 'add_faq',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add FAQ'),
          ),
        ),
      ],
    );
  }
}

class _PageTab extends StatefulWidget {
  const _PageTab({
    super.key,
    required this.token,
    required this.service,
    required this.pageKey,
    required this.page,
    required this.onSaved,
  });

  final String token;
  final AdminSettingsService service;
  final String pageKey;
  final AdminContentPage? page;
  final VoidCallback onSaved;

  @override
  State<_PageTab> createState() => _PageTabState();
}

class _PageTabState extends State<_PageTab> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.page?.title ?? '');
    _bodyController = TextEditingController(text: widget.page?.body ?? '');
  }

  @override
  void didUpdateWidget(covariant _PageTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page?.title != widget.page?.title) _titleController.text = widget.page?.title ?? '';
    if (oldWidget.page?.body != widget.page?.body) _bodyController.text = widget.page?.body ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateContentPage(
        widget.pageKey,
        title: _titleController.text.trim(),
        body: _bodyController.text,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showSuccess(context, 'Saved.');
      widget.onSaved();
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Page title', border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _bodyController,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Page content',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: _saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
      ],
    );
  }
}
