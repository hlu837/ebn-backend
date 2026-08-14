import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Search bar used at the top of every admin list screen (Agents, Users,
/// Transactions, Support Inbox). Purely presentational — [onChanged] is
/// left for the caller to wire up to real filtering later.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.hintText, this.onChanged});

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.pill), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.pill), borderSide: const BorderSide(color: AppColors.border)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
      ),
    );
  }
}

/// Row of filter chips, e.g. "All / Online / Offline" or "Open / Resolved".
class AdminFilterChips extends StatelessWidget {
  const AdminFilterChips({super.key, required this.options, required this.selected, required this.onSelected});

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return ChoiceChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (_) => onSelected(option),
            selectedColor: AppColors.primaryYellow,
            backgroundColor: AppColors.card,
            side: const BorderSide(color: AppColors.border),
            labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isSelected ? AppColors.ink : AppColors.slate),
          );
        },
      ),
    );
  }
}

/// A generic tappable card row: leading circle icon/avatar, title,
/// subtitle, optional trailing badge, and a chevron. Used across Agents,
/// Users, Transactions, and Support Inbox list screens.
class AdminEntityRow extends StatelessWidget {
  const AdminEntityRow({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.trailingColor,
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.18), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(leadingIcon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trailingColor ?? AppColors.slate).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    trailingText!,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: trailingColor ?? AppColors.slate),
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small stat card used on Reports/Transactions summary rows.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }
}

/// Empty-state block for any list screen with nothing to show.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({super.key, required this.message, this.icon = Icons.inbox_rounded});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.slate),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
