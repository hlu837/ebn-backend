import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/sell_request.dart';
import '../providers/sell_request_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// The Agent/Broker's in-person inspection report — photos, a video, and
/// written notes about the property — submitted for Admin's final
/// approval before it goes live. No real camera/file picker in this
/// frontend-only demo: "Add photo/video" just appends a mock thumbnail.
class AgentPropertyReportScreen extends StatefulWidget {
  const AgentPropertyReportScreen({super.key, required this.request});

  final SellRequest request;

  @override
  State<AgentPropertyReportScreen> createState() => _AgentPropertyReportScreenState();
}

class _AgentPropertyReportScreenState extends State<AgentPropertyReportScreen> {
  final _notesController = TextEditingController();
  final List<ReportMediaItem> _media = [];
  bool _isSubmitting = false;
  int _mockId = 1;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.request.reportNotes ?? '';
    _media.addAll(widget.request.reportMedia);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addMedia(bool isVideo) {
    setState(() => _media.add(ReportMediaItem(id: 'm${_mockId++}', isVideo: isVideo)));
  }

  void _removeMedia(String id) {
    setState(() => _media.removeWhere((m) => m.id == id));
  }

  Future<void> _submit() async {
    if (_media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo before submitting.')),
      );
      return;
    }
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short written report before submitting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700)); // mock upload
    if (!mounted) return;

    try {
      await context.read<SellRequestController>().agentSubmitReport(
            widget.request.id,
            agentId: widget.request.agentId!,
            media: _media,
            notes: _notesController.text.trim(),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted — waiting on Admin approval.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final wasRejected = r.status == SellRequestStatus.reportRejected;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Inspection report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('${r.category.label} · ${r.city}', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
                const SizedBox(height: 6),
                Text(r.addressLine, style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.call_outlined, size: 14, color: AppColors.slate),
                    const SizedBox(width: 4),
                    Text('${r.ownerName} · ${r.ownerPhone}', style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          if (wasRejected) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sent back by Admin: ${r.reportRejectionReason ?? 'Needs revision.'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Text('Photos & video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text('Document the property in person — condition, rooms, exterior.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _media) _MediaThumb(item: item, onRemove: () => _removeMedia(item.id)),
              _AddMediaButton(icon: Icons.add_a_photo_outlined, label: 'Photo', onTap: () => _addMedia(false)),
              _AddMediaButton(icon: Icons.videocam_outlined, label: 'Video', onTap: () => _addMedia(true)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Written report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Condition on arrival, any discrepancies from the listing, verified ownership docs, etc.',
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: wasRejected ? 'Resubmit report' : 'Submit report to Admin',
            isLoading: _isSubmitting,
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.item, required this.onRemove});
  final ReportMediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.md)),
          alignment: Alignment.center,
          child: Icon(item.isVideo ? Icons.videocam_rounded : Icons.image_rounded, color: AppColors.primaryYellow, size: 26),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border, width: 1.4)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.ink, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
