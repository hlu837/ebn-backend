import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/broker.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/user_role.dart';
import '../providers/favorites_controller.dart';
import '../services/asset_service.dart';
import '../theme/landing_colors.dart';
import '../widgets/asset_list_card.dart';
import 'broker_chat_screen.dart';
import 'signup_screen.dart';

/// A broker's public profile — reached by tapping a broker from the
/// "Find brokers" list or from a pin on [BrokerMapScreen].
///
/// Shows their membership tier and, per the platform's posting rules, only
/// the listings they're actually allowed to have live:
///  - Gold / Diamond brokers: listings across every category they work in.
///  - Silver / Bronze brokers: listings in a single locked category only.
class BrokerProfileScreen extends StatefulWidget {
  final Broker broker;

  /// The signed-in visitor, if any. When present, "Chat about this
  /// listing" opens a real conversation via [BrokerChatScreen]; when
  /// absent (guest browsing), it still routes to sign-up as before.
  final AppUser? currentUser;

  const BrokerProfileScreen({super.key, required this.broker, this.currentUser});

  @override
  State<BrokerProfileScreen> createState() => _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends State<BrokerProfileScreen> {
  final _assetService = AssetService();
  List<Asset> _listings = const [];
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
      final rows = await _assetService.fetchByBroker(widget.broker.id);
      if (!mounted) return;
      setState(() {
        // Only show what a visitor should actually see on a public
        // profile — same rule the visitor feed applies elsewhere.
        _listings = rows.where((a) => a.status == AssetStatus.active).toList();
        _loading = false;
      });
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final broker = widget.broker;
    final currentUser = widget.currentUser;
    // Enforce the membership-tier posting restriction even defensively here,
    // in case a broker's real listings ever drift from their tier rules.
    final listings = broker.tier.canPostAnyCategory
        ? _listings
        : _listings.where((a) => a.category == (broker.lockedCategory ?? a.category)).toList();

    return Scaffold(
      backgroundColor: LandingColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: LandingColors.foreground,
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text('Broker profile',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _ProfileHeader(broker: broker),
                  const SizedBox(height: 16),
                  _TierCard(broker: broker),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('${listings.length} listing${listings.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.foreground)),
                      const Spacer(),
                      if (!broker.tier.canPostAnyCategory && broker.lockedCategory != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: LandingColors.card, border: Border.all(color: LandingColors.border), borderRadius: BorderRadius.circular(999)),
                          child: Text('Only posts ${broker.lockedCategory!.label}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LandingColors.muted)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_error != null)
                    Container(
                      decoration: BoxDecoration(color: LandingColors.card, border: Border.all(color: LandingColors.border), borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: LandingColors.muted, fontSize: 13)),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: _load, child: const Text('Try again')),
                        ],
                      ),
                    )
                  else if (listings.isEmpty)
                    Container(
                      decoration: BoxDecoration(color: LandingColors.card, border: Border.all(color: LandingColors.border), borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      alignment: Alignment.center,
                      child: const Text('No active listings from this broker yet.', style: TextStyle(color: LandingColors.muted)),
                    )
                  else
                    ...listings.map((asset) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ListingWithChat(broker: broker, asset: asset, currentUser: currentUser),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Broker broker;
  const _ProfileHeader({required this.broker});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: LandingColors.gold, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(broker.initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: LandingColors.goldFg)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(broker.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: LandingColors.foreground)),
              const SizedBox(height: 2),
              Text('${broker.company} · ${broker.city}', style: const TextStyle(fontSize: 13, color: LandingColors.muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: LandingColors.gold),
                  const SizedBox(width: 2),
                  Text(broker.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.foreground)),
                  const SizedBox(width: 10),
                  Icon(broker.tier.icon, size: 15, color: broker.tier.color),
                  const SizedBox(width: 3),
                  Text('${broker.tier.label} member', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: broker.tier.color)),
                ],
              ),
              if (broker.addressLine != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: LandingColors.muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(broker.addressLine!, style: const TextStyle(fontSize: 12.5, color: LandingColors.muted))),
                  ],
                ),
              ],
              if (broker.phone != null) ...[
                const SizedBox(height: 10),
                _CallButton(broker: broker),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final Broker broker;
  const _CallButton({required this.broker});

  void _call(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SignUpScreen(initialRole: UserRole.user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _call(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: LandingColors.gold,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_rounded, size: 15, color: LandingColors.goldFg),
              SizedBox(width: 6),
              Text('Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LandingColors.goldFg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final Broker broker;
  const _TierCard({required this.broker});

  @override
  Widget build(BuildContext context) {
    if (broker.bio != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(broker.bio!, style: const TextStyle(fontSize: 13.5, color: LandingColors.foreground, height: 1.4)),
          const SizedBox(height: 14),
          _MembershipBanner(broker: broker),
        ],
      );
    }
    return _MembershipBanner(broker: broker);
  }
}

class _MembershipBanner extends StatelessWidget {
  final Broker broker;
  const _MembershipBanner({required this.broker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: broker.tier.color.withOpacity(0.12),
        border: Border.all(color: broker.tier.color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(broker.tier.icon, color: broker.tier.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${broker.tier.label} membership', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: broker.tier.color)),
                const SizedBox(height: 3),
                Text(broker.tier.description, style: const TextStyle(fontSize: 12, color: LandingColors.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingWithChat extends StatelessWidget {
  final Broker broker;
  final Asset asset;
  final AppUser? currentUser;
  const _ListingWithChat({required this.broker, required this.asset, this.currentUser});

  void _onChatTap(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const SignUpScreen(initialRole: UserRole.user),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrokerChatScreen(broker: broker, asset: asset, currentUser: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = context.select<FavoritesController, bool>((f) => f.isFavorite(asset.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssetListCard(
          asset: asset,
          actionLabel: 'View details',
          isSaved: isSaved,
          onSaveToggle: (_) => context.read<FavoritesController>().toggle(asset.id),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _onChatTap(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: LandingColors.foreground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: LandingColors.primaryFg),
                  SizedBox(width: 8),
                  Text('Chat about this listing',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.primaryFg)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
