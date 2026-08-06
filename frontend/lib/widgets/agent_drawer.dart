import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Membership tiers an agent can hold. Extend this list as new tiers launch.
enum AgentTier { bronze, silver, gold, diamond }

extension AgentTierX on AgentTier {
  String get label {
    switch (this) {
      case AgentTier.bronze:
        return 'Bronze Member';
      case AgentTier.silver:
        return 'Silver Member';
      case AgentTier.gold:
        return 'Gold Member';
      case AgentTier.diamond:
        return 'Diamond Member';
    }
  }

  /// Accent color used for the badge background, icon, and text.
  Color get color {
    switch (this) {
      case AgentTier.bronze:
        return const Color(0xFFB2703C);
      case AgentTier.silver:
        return const Color(0xFF8A8D93);
      case AgentTier.gold:
        return const Color(0xFFC79A2E);
      case AgentTier.diamond:
        return const Color(0xFF2E8FDE);
    }
  }

  IconData get icon => this == AgentTier.diamond ? Icons.diamond_rounded : Icons.workspace_premium_rounded;
}

/// Bundles all the navigation callbacks the drawer needs, so a screen can
/// wire this up once with Navigator calls (or a router) without the drawer
/// itself knowing anything about routes.
class AgentDrawerActions {
  final VoidCallback? onDashboard;
  final VoidCallback? onPropertyManagement;
  final VoidCallback? onCustomers;
  final VoidCallback? onReferrals;
  final VoidCallback? onBrokerNetwork;
  final VoidCallback? onVisibilityProfile;
  final VoidCallback? onWallet;
  final VoidCallback? onMembership;
  final VoidCallback? onCommunication;
  final VoidCallback? onSchedule;
  final VoidCallback? onSettings;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;

  const AgentDrawerActions({
    this.onDashboard,
    this.onPropertyManagement,
    this.onCustomers,
    this.onReferrals,
    this.onBrokerNetwork,
    this.onVisibilityProfile,
    this.onWallet,
    this.onMembership,
    this.onCommunication,
    this.onSchedule,
    this.onSettings,
    this.onSupport,
    this.onLogout,
  });
}

/// The primary navigation drawer for the Agent role.
///
/// Usage:
/// ```dart
/// Scaffold(
///   drawer: AgentDrawer(
///     agentName: 'Fadi Alkhatib',
///     avatarUrl: agent.avatarUrl,
///     tier: AgentTier.diamond,
///     isOnline: agentProvider.isOnline,
///     onOnlineChanged: (value) => agentProvider.setOnline(value),
///     actions: AgentDrawerActions(
///       onDashboard: () => Navigator.pushNamed(context, '/agent'),
///       onPropertyManagement: () => Navigator.pushNamed(context, '/agent/properties'),
///       onCustomers: () => Navigator.pushNamed(context, '/agent/customers'),
///       onReferrals: () => Navigator.pushNamed(context, '/agent/referrals'),
///       onBrokerNetwork: () => Navigator.pushNamed(context, '/agent/network'),
///       onVisibilityProfile: () => Navigator.pushNamed(context, '/agent/profile'),
///       onWallet: () => Navigator.pushNamed(context, '/agent/wallet'),
///       onMembership: () => Navigator.pushNamed(context, '/agent/membership'),
///       onCommunication: () => Navigator.pushNamed(context, '/agent/inbox'),
///       onSchedule: () => Navigator.pushNamed(context, '/agent/schedule'),
///       onSettings: () => Navigator.pushNamed(context, '/agent/settings'),
///       onSupport: () => Navigator.pushNamed(context, '/agent/support'),
///       onLogout: () => authProvider.signOut(),
///     ),
///   ),
///   body: ...,
/// )
/// ```
class AgentDrawer extends StatelessWidget {
  const AgentDrawer({
    super.key,
    required this.agentName,
    required this.isOnline,
    required this.onOnlineChanged,
    this.avatarUrl,
    this.tier = AgentTier.gold,
    this.actions = const AgentDrawerActions(),
  });

  final String agentName;
  final String? avatarUrl;
  final AgentTier tier;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final AgentDrawerActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cloud,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(
              agentName: agentName,
              avatarUrl: avatarUrl,
              tier: tier,
              isOnline: isOnline,
              onOnlineChanged: onOnlineChanged,
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () => _tap(context, actions.onDashboard),
                  ),
                  _DrawerItem(
                    icon: Icons.apartment_outlined,
                    label: 'Property Management',
                    onTap: () => _tap(context, actions.onPropertyManagement),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Customers',
                    onTap: () => _tap(context, actions.onCustomers),
                  ),
                  _DrawerItem(
                    icon: Icons.handshake_outlined,
                    label: 'Referrals',
                    onTap: () => _tap(context, actions.onReferrals),
                  ),
                  _DrawerItem(
                    icon: Icons.public,
                    label: 'Broker Network',
                    onTap: () => _tap(context, actions.onBrokerNetwork),
                  ),
                  _DrawerItem(
                    icon: Icons.star_outline,
                    label: 'Visibility & Profile',
                    onTap: () => _tap(context, actions.onVisibilityProfile),
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    onTap: () => _tap(context, actions.onWallet),
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Membership',
                    onTap: () => _tap(context, actions.onMembership),
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Communication',
                    onTap: () => _tap(context, actions.onCommunication),
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Schedule',
                    onTap: () => _tap(context, actions.onSchedule),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _tap(context, actions.onSettings),
                  ),
                  _DrawerItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Support',
                    onTap: () => _tap(context, actions.onSupport),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _LogoutTile(onTap: () => _tap(context, actions.onLogout)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// Closes the drawer before firing the caller's callback, matching the
  /// standard Material drawer-navigation pattern.
  void _tap(BuildContext context, VoidCallback? callback) {
    Navigator.of(context).pop();
    callback?.call();
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.agentName,
    required this.tier,
    required this.isOnline,
    required this.onOnlineChanged,
    this.avatarUrl,
  });

  final String agentName;
  final String? avatarUrl;
  final AgentTier tier;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.border,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person_rounded, color: AppColors.slate, size: 30)
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _StatusDot(isOnline: isOnline),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _TierBadge(tier: tier),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _OnlineToggleRow(isOnline: isOnline, onChanged: onOnlineChanged),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final AgentTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tier.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: 13, color: tier.color),
          const SizedBox(width: 4),
          Text(
            tier.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: tier.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.slate;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.card, width: 2),
      ),
      child: isOnline
          ? const _PulsingDot()
          : null,
    );
  }
}

/// Small looping pulse animation drawn behind the solid online dot.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 1.6);
        final opacity = (1 - _controller.value).clamp(0.0, 1.0);
        return Center(
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnlineToggleRow extends StatelessWidget {
  const _OnlineToggleRow({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: isOnline ? AppColors.success : AppColors.slate,
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isOnline ? AppColors.success : AppColors.slate,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: isOnline,
            onChanged: onChanged,
            activeColor: AppColors.success,
            inactiveThumbColor: AppColors.slate,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          hoverColor: AppColors.border.withOpacity(0.4),
          splashColor: AppColors.primaryYellow.withOpacity(0.25),
          highlightColor: AppColors.primaryYellow.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.ink),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          hoverColor: AppColors.danger.withOpacity(0.08),
          splashColor: AppColors.danger.withOpacity(0.15),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 22, color: AppColors.danger),
                SizedBox(width: AppSpacing.md),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
