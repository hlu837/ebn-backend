import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

const _kAccentRed = AppColors.primaryYellow;

enum _CampaignStatus { active, upcoming, ended }

class _Campaign {
  final String title;
  final String description;
  final String badge;
  final _CampaignStatus status;
  final IconData icon;

  const _Campaign({
    required this.title,
    required this.description,
    required this.badge,
    required this.status,
    required this.icon,
  });
}

/// TODO: replace with a real `GET /api/affiliates/campaigns` call once the
/// affiliate program has a backend — the "Summer Real Estate Drive" promo
/// on the dashboard banner is the same mock campaign shown here as the
/// active one.
const List<_Campaign> _kMockCampaigns = [
  _Campaign(
    title: 'Summer Real Estate Drive',
    description: 'Earn double commission (4%) on every house and apartment sale you refer through August.',
    badge: '4% Commission',
    status: _CampaignStatus.active,
    icon: Icons.wb_sunny_outlined,
  ),
  _Campaign(
    title: 'New Agent Referral Bonus',
    description: 'Refer a new verified agent to the platform and earn a flat 5,000 ETB bonus once they close their first deal.',
    badge: '5,000 ETB bonus',
    status: _CampaignStatus.active,
    icon: Icons.person_add_alt_1_outlined,
  ),
  _Campaign(
    title: 'Vehicle Marketplace Launch',
    description: 'Special 3% commission tier on all vehicle listings, launching alongside the new vehicles category.',
    badge: '3% Commission',
    status: _CampaignStatus.upcoming,
    icon: Icons.directions_car_outlined,
  ),
  _Campaign(
    title: 'New Year Kickoff',
    description: 'Boosted commission tiers to open the year strong across all categories.',
    badge: '3.5% Commission',
    status: _CampaignStatus.ended,
    icon: Icons.celebration_outlined,
  ),
];

/// Promotional campaigns the Affiliater can join and share — matches the
/// dashboard's seasonal promo banner, plus upcoming and past campaigns.
class AffiliateCampaignsScreen extends StatelessWidget {
  const AffiliateCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final active = _kMockCampaigns.where((c) => c.status == _CampaignStatus.active).toList();
    final upcoming = _kMockCampaigns.where((c) => c.status == _CampaignStatus.upcoming).toList();
    final ended = _kMockCampaigns.where((c) => c.status == _CampaignStatus.ended).toList();

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Campaigns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (active.isNotEmpty) ...[
            _SectionLabel('Active'),
            const SizedBox(height: AppSpacing.sm),
            ...active.map((c) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: _CampaignCard(campaign: c))),
          ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _SectionLabel('Upcoming'),
            const SizedBox(height: AppSpacing.sm),
            ...upcoming.map((c) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: _CampaignCard(campaign: c))),
          ],
          if (ended.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _SectionLabel('Ended'),
            const SizedBox(height: AppSpacing.sm),
            ...ended.map((c) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: _CampaignCard(campaign: c))),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.3));
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final _Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final ended = campaign.status == _CampaignStatus.ended;
    final upcoming = campaign.status == _CampaignStatus.upcoming;

    return Opacity(
      opacity: ended ? 0.55 : 1,
      child: Container(
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _kAccentRed.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadii.md)),
                  child: Icon(campaign.icon, color: _kAccentRed, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(campaign.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ended
                              ? AppColors.border
                              : upcoming
                                  ? const Color(0xFFFFF3D6)
                                  : const Color(0xFFE3F6EA),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          ended ? 'Ended' : (upcoming ? 'Upcoming' : campaign.badge),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ended
                                ? AppColors.slate
                                : upcoming
                                    ? const Color(0xFFB8860B)
                                    : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(campaign.description, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.slate, height: 1.4)),
            if (campaign.status == _CampaignStatus.active) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  label: 'Share Campaign',
                  borderColor: _kAccentRed,
                  textColor: _kAccentRed,
                  onPressed: () => AppToast.showSuccess(context, '"${campaign.title}" link copied — share it anywhere.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
