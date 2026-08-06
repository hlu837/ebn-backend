import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/order_request.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_drawer.dart' show AgentTier, AgentTierX;
import '../widgets/listing_intent_sheet.dart';
import 'agent_broker_network_screen.dart';
import 'agent_membership_screen.dart';
import 'agent_schedule_screen.dart';
import 'agent_sell_requests_screen.dart';
import 'agent_tasks_screen.dart';
import 'agent_wallet_screen.dart';
import 'placeholder_page.dart';
import 'rent_property_form_screen.dart';
import 'sell_property_form_screen.dart';

/// The Agent workspace "Home" tab — wallet balance, quick actions, a
/// property-management preview, active leads, membership plan, and the
/// referral / collaboration hub. Everything below the fold used to live
/// behind the side drawer; now the dashboard itself is the front door.
class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({
    super.key,
    required this.user,
    required this.tier,
    required this.isOnline,
    required this.onOnlineChanged,
    required this.hasLocation,
    required this.settingLocation,
    required this.onSetLocation,
    required this.walletBalance,
    required this.properties,
    required this.activeLeads,
    required this.availableLeadsCount,
    required this.onSwitchToLeadsTab,
    this.unreadNotifications = 0,
    this.onNotificationsTap,
  });

  final AppUser user;
  final AgentTier tier;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final bool hasLocation;
  final bool settingLocation;
  final VoidCallback onSetLocation;
  final double walletBalance;
  final List<Asset> properties;
  final List<OrderRequest> activeLeads;
  final int availableLeadsCount;
  final VoidCallback onSwitchToLeadsTab;
  final int unreadNotifications;
  final VoidCallback? onNotificationsTap;

  int get _totalLeads => activeLeads.length + availableLeadsCount;

  void _openPlaceholder(BuildContext context, {required String title, required IconData icon, required String description, List<String> bullets = const []}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceholderPage(title: title, icon: icon, description: description, bullets: bullets),
    ));
  }

  /// Same Sell/Rent flow as the Visitor side's "+" and the Agent bottom
  /// nav's raised "+" — real forms, not a placeholder. Selling goes
  /// through `isAgentListing: true` since this is the Agent's own
  /// property, not one they'll later claim/inspect for someone else.
  Future<void> _openListingIntent(BuildContext context) async {
    final intent = await showListingIntentSheet(context);
    if (intent == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => intent == ListingIntent.sell
          ? SellPropertyFormScreen(user: user, isAgentListing: true)
          : RentPropertyFormScreen(user: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        children: [
          _Header(
            user: user,
            tier: tier,
            isOnline: isOnline,
            onOnlineChanged: onOnlineChanged,
            hasLocation: hasLocation,
            settingLocation: settingLocation,
            onSetLocation: onSetLocation,
            unreadNotifications: unreadNotifications,
            onNotificationsTap: onNotificationsTap,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Wallet Balance',
                  value: 'ETB ${_formatMoney(walletBalance)}',
                  action: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentWalletScreen(user: user))),
                    child: const Text('Withdraw', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'My Leads',
                  value: '$_totalLeads',
                  action: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: onSwitchToLeadsTab,
                    child: const Text('View all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_rounded,
                  label: 'Post Ad',
                  filled: true,
                  onTap: () => _openListingIntent(context),
                ),
              ),
              Expanded(
                child: _QuickAction(icon: Icons.groups_outlined, label: 'My Leads', onTap: onSwitchToLeadsTab),
              ),
              Expanded(
                child: _QuickAction(
                  icon: Icons.checklist_rounded,
                  label: 'Tasks',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentTasksScreen(user: user))),
                ),
              ),
              Expanded(
                child: _QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentScheduleScreen(user: user))),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(child: Text('Property Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink))),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentSellRequestsScreen(user: user))),
                child: const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (properties.isEmpty)
            _EmptyStrip(text: 'No listings yet — post your first property.')
          else
            for (final asset in properties.take(2)) ...[
              _PropertyCard(
                asset: asset,
                onEdit: () => _openPlaceholder(context, title: 'Edit listing', icon: Icons.edit_outlined, description: 'Update "${asset.title}" — price, photos, and details.'),
                onBoost: () => _openPlaceholder(context, title: 'Boost listing', icon: Icons.trending_up_rounded, description: 'Pay to feature "${asset.title}" higher in search results.'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Expanded(child: Text('Active Leads', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink))),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: onSwitchToLeadsTab,
                child: const Text('My Leads', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activeLeads.isEmpty)
            _EmptyStrip(text: hasLocation ? 'No claimed leads yet — check Leads for nearby requests.' : 'Set your location under Leads to start receiving requests.')
          else
            for (final lead in activeLeads.take(3)) ...[
              _LeadCard(lead: lead),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.md),
          _MembershipBanner(
            tier: tier,
            onUpgrade: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentMembershipScreen(user: user, initialTier: tier))),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Collaboration Hub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          _ReferralCard(
            onExplore: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgentBrokerNetworkScreen(user: user))),
          ),
        ],
      ),
    );
  }
}

String _formatMoney(double value) {
  final s = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buffer.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.tier,
    required this.isOnline,
    required this.onOnlineChanged,
    required this.hasLocation,
    required this.settingLocation,
    required this.onSetLocation,
    this.unreadNotifications = 0,
    this.onNotificationsTap,
  });

  final AppUser user;
  final AgentTier tier;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final bool hasLocation;
  final bool settingLocation;
  final VoidCallback onSetLocation;
  final int unreadNotifications;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.border,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tier.icon, size: 13, color: tier.color),
                      const SizedBox(width: 4),
                      Text(tier.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tier.color)),
                    ],
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNotificationsTap,
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                        style: const TextStyle(color: AppColors.ink, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            Switch.adaptive(
              value: isOnline,
              onChanged: onOnlineChanged,
              activeColor: AppColors.success,
              inactiveThumbColor: AppColors.slate,
              inactiveTrackColor: AppColors.border,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryYellow.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.primaryYellow.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryYellow),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasLocation ? 'Serving requests near your current location' : 'Set your service area to receive nearby leads',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: settingLocation ? null : onSetLocation,
                child: Text(
                  settingLocation ? 'Updating…' : 'Update',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryYellow),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.action});
  final String label;
  final String value;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 6),
          action,
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: filled ? AppColors.primaryYellow : AppColors.card,
                shape: BoxShape.circle,
                border: filled ? null : Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: filled ? Colors.white : AppColors.ink, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.asset, required this.onEdit, required this.onBoost});
  final Asset asset;
  final VoidCallback onEdit;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: asset.imageUrl != null
                    ? Image.network(asset.imageUrl!, width: 68, height: 68, fit: BoxFit.cover)
                    : Container(width: 68, height: 68, color: AppColors.border, child: const Icon(Icons.home_outlined, color: AppColors.slate)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${asset.priceCurrency} ${_formatMoney(asset.priceAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
                    const SizedBox(height: 3),
                    Text(
                      [if (asset.addressLine != null) asset.addressLine!, if (asset.city != null) asset.city!].join(', '),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          Row(
            children: [
              Expanded(child: _CardActionButton(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit)),
              const SizedBox(width: 8),
              Expanded(child: _CardActionButton(icon: Icons.trending_up_rounded, label: 'Boost', onTap: onBoost)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.ink),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});
  final OrderRequest lead;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: lead.requesterPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.border,
            child: Text(
              lead.requesterName.isNotEmpty ? lead.requesterName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.requesterName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(lead.title, style: const TextStyle(fontSize: 12, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _RoundIconButton(icon: Icons.call_rounded, onTap: _call),
          const SizedBox(width: 8),
          _RoundIconButton(
            icon: Icons.calendar_month_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PlaceholderPage(
                title: 'Schedule',
                icon: Icons.calendar_month_outlined,
                description: 'Book a tour with this lead.',
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryYellow.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, size: 17, color: AppColors.primaryYellow)),
      ),
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner({required this.tier, required this.onUpgrade});
  final AgentTier tier;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEMBERSHIP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryYellow, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('${tier.label.replaceAll(' Member', '')} Plan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onUpgrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(AppRadii.pill)),
                    child: const Text('Upgrade Plan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Icon(tier.icon, color: tier.color, size: 42),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.handshake_outlined, color: AppColors.primaryYellow, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Referral Network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Refer clients to nearby brokers and earn up to 10% commission sharing.',
            style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onExplore, child: const Text('Explore Ready Realtors')),
          ),
        ],
      ),
    );
  }
}
