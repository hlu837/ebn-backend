import 'package:flutter/material.dart';
import '../models/broker.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';

/// Admin's read-only detail page for a single agent — real profile data
/// from the Broker Network directory (`GET /api/agents`, via the [Broker]
/// model). Active-claims and listing-history sections aren't backed by a
/// per-agent endpoint yet, so they're left as honest empty states rather
/// than sample rows — wire those up once `GET /api/agents/:id/claims`
/// (or similar) exists.
class AdminAgentDetailScreen extends StatelessWidget {
  const AdminAgentDetailScreen({super.key, required this.agent});

  final Broker agent;

  @override
  Widget build(BuildContext context) {
    final online = agent.hasPreciseLocation;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Agent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.ink,
                  child: Text(
                    agent.initials,
                    style: const TextStyle(color: AppColors.primaryYellow, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        agent.phone?.isNotEmpty == true ? agent.phone! : 'No phone on file',
                        style: const TextStyle(fontSize: 13, color: AppColors.slate),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (online ? AppColors.success : AppColors.slate).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              online ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: online ? AppColors.success : AppColors.slate),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: agent.tier.color.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(agent.tier.icon, size: 12, color: agent.tier.color),
                                const SizedBox(width: 4),
                                Text(agent.tier.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: agent.tier.color)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (agent.company.isNotEmpty || agent.city.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (agent.company.isNotEmpty)
                      _InfoRow(icon: Icons.apartment_outlined, label: 'Agency / license', value: agent.company),
                    if (agent.city.isNotEmpty) ...[
                      if (agent.company.isNotEmpty) const SizedBox(height: 8),
                      _InfoRow(icon: Icons.place_outlined, label: 'City', value: agent.city),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                AdminStatCard(value: agent.rating > 0 ? agent.rating.toStringAsFixed(1) : '—', label: 'Avg Rating'),
                const SizedBox(width: AppSpacing.sm),
                AdminStatCard(value: agent.specialties.length.toString(), label: 'Specialties'),
                const SizedBox(width: AppSpacing.sm),
                AdminStatCard(value: agent.tier.canPostAnyCategory ? 'Any' : '1', label: 'Categories'),
              ],
            ),

            if (agent.bio != null && agent.bio!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const Text('Bio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: AppSpacing.sm),
              Text(agent.bio!, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4)),
            ],

            const SizedBox(height: AppSpacing.xl),
            const Text('Active claims', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: AppSpacing.sm),
            // Not backed by a per-agent endpoint yet — an honest empty
            // state until GET /api/agents/:id/claims (or similar) exists,
            // rather than showing fabricated rows.
            const AdminEmptyState(message: 'Active claims aren\'t wired up yet for this view.', icon: Icons.assignment_outlined),

            const SizedBox(height: AppSpacing.lg),
            const Text('Listing history', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: AppSpacing.sm),
            const AdminEmptyState(message: 'Listing history isn\'t wired up yet for this view.', icon: Icons.history_rounded),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.slate),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
