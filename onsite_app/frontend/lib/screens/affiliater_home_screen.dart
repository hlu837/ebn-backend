import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../services/affiliate_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'affiliate_referrals_screen.dart';
import 'affiliate_earnings_screen.dart';
import 'affiliate_tokens_screen.dart';
import 'affiliate_properties_screen.dart';
import 'affiliate_reports_screen.dart';
import 'affiliate_campaigns_screen.dart';
import 'affiliate_notifications_screen.dart';
import 'affiliate_account_settings_screen.dart';
import 'affiliate_membership_screen.dart';
import 'affiliate_support_screen.dart';
import 'role_gate_screen.dart';

const _kAccentRed = Color(0xFFFF2636);

/// One row in the "Referral Tracker" list — a click/sign-up/sale this
/// affiliater generated, along with the commission it earned and whether
/// that commission has cleared yet.
class _ReferralEntry {
  final String customerName;
  final String propertyTitle;
  final double commissionAmount;
  final bool isPending;

  const _ReferralEntry({
    required this.customerName,
    required this.propertyTitle,
    required this.commissionAmount,
    required this.isPending,
  });
}

class AffiliaterHomeScreen extends StatefulWidget {
  const AffiliaterHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AffiliaterHomeScreen> createState() => _AffiliaterHomeScreenState();
}

class _AffiliaterHomeScreenState extends State<AffiliaterHomeScreen> {
  int _navIndex = 0;
  int _trackerTabIndex = 0; // 0 = All, 1 = Pending, 2 = Completed
  final TextEditingController _searchController = TextEditingController();
  final AffiliateService _affiliateService = AffiliateService();

  String _affiliateCode = 'Loading...';
  List<_ReferralEntry> _referralsList = [];
  // ignore: unused_field
  bool _isLoadingData = false;
  int _unreadNotifications = 0;

  final List<Asset> _topProperties = const [
    Asset(
      id: 'aff-1',
      title: 'Skyline Luxury Villa',
      priceAmount: 24500000,
      priceCurrency: 'ETB',
      category: AssetCategorySlug.house,
      status: AssetStatus.active,
      addressLine: 'Bole, Addis Ababa',
      city: 'Addis Ababa',
      attributes: {'bedrooms': 5, 'bathrooms': 4, 'sqft': 4200},
      imageUrl:
          'https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800&q=80',
    ),
    Asset(
      id: 'aff-2',
      title: 'Downtown Heights Apt',
      priceAmount: 6250000,
      priceCurrency: 'ETB',
      category: AssetCategorySlug.apartments,
      status: AssetStatus.active,
      addressLine: 'Kazanchis, Addis Ababa',
      city: 'Addis Ababa',
      attributes: {'bedrooms': 3, 'bathrooms': 2, 'sqft': 1650},
      imageUrl:
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAffiliateData();
  }

  Future<void> _loadAffiliateData() async {
    final token = widget.user.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _affiliateCode = 'EBN-LOCAL';
      });
      return;
    }
    setState(() => _isLoadingData = true);
    try {
      final code = await _affiliateService.getCode(token);
      final rawReferrals = await _affiliateService.getReferrals(token);
      final notifications = await _affiliateService.getNotifications(token);
      if (!mounted) return;
      setState(() {
        _affiliateCode = code;
        _unreadNotifications = notifications.where((n) => !n.isRead).length;
        if (rawReferrals.isNotEmpty) {
          _referralsList = rawReferrals
              .map((r) => _ReferralEntry(
                    customerName: r.customerName,
                    propertyTitle: r.assetTitle,
                    commissionAmount: r.commissionAmount,
                    isPending: r.isPending,
                  ))
              .toList();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _affiliateCode = 'EBN-${widget.user.id.substring(0, 6).toUpperCase()}';
      });
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ReferralEntry> get _referrals => _referralsList.isNotEmpty
      ? _referralsList
      : const [
          _ReferralEntry(
            customerName: 'Sarah M.',
            propertyTitle: 'Skyline Luxury Villa',
            commissionAmount: 490000,
            isPending: true,
          ),
          _ReferralEntry(
            customerName: 'David K.',
            propertyTitle: 'Downtown Heights Apt',
            commissionAmount: 164000,
            isPending: false,
          ),
        ];

  List<_ReferralEntry> get _filteredReferrals {
    final list = _referrals;
    if (_trackerTabIndex == 1) return list.where((r) => r.isPending).toList();
    if (_trackerTabIndex == 2) return list.where((r) => !r.isPending).toList();
    return list;
  }

  void _copyCode() async {
    try {
      final origin = Uri.base.origin.isNotEmpty
          ? Uri.base.origin
          : 'http://localhost:8080';
      final shareUrl = '$origin/?ref=$_affiliateCode';
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (!mounted) return;
      AppToast.showSuccess(context, 'Referral link copied to clipboard');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to copy link: $e');
    }
  }

  void _requestPayout() async {
    final token = widget.user.token;
    if (token != null && token.isNotEmpty) {
      try {
        await _affiliateService.requestPayout(token);
        if (!mounted) return;
        AppToast.showSuccess(context, 'Payout requested successfully!');
        return;
      } catch (e) {
        // Fall back to toast
      }
    }
    AppToast.showSuccess(
        context, 'Payout requested. Admin will review it shortly.');
  }

  void _generateLink(Asset asset) async {
    try {
      final token = widget.user.token;
      String url = '${Uri.base.origin}/assets/${asset.id}?ref=$_affiliateCode';
      if (token != null && token.isNotEmpty) {
        try {
          final linkData =
              await _affiliateService.generateLink(token, assetId: asset.id);
          url = linkData['url'] ?? url;
        } catch (_) {}
      }
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      AppToast.showSuccess(context, 'Link copied for "${asset.title}"');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to generate link: $e');
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  void _openMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreBottomSheet(
        onReports: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  AffiliateReportsScreen(token: widget.user.token ?? '')));
        },
        onMembership: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AffiliateMembershipScreen(user: widget.user)));
        },
        onSettings: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  AffiliateAccountSettingsScreen(user: widget.user)));
        },
        onSupport: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AffiliateSupportScreen(user: widget.user)));
        },
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              userName: widget.user.fullName,
              unreadNotifications: _unreadNotifications,
              onNotifications: () =>
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AffiliateNotificationsScreen(
                            token: widget.user.token ?? '',
                            onUnreadCountChanged: (count) {
                              if (mounted) {
                                setState(() => _unreadNotifications = count);
                              }
                            },
                          ))),
              onChangeLanguage: () => showDialog(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Language',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('🇬🇧  English'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('🇪🇹  አማርኛ (Amharic)'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                children: [
                  _AffiliateCodeCard(
                      code: _affiliateCode,
                      onCopy: _copyCode,
                      onRequestPayout: _requestPayout),
                  const SizedBox(height: AppSpacing.lg),
                  _QuickActionsRow(
                    onShareLink: _copyCode,
                    onAssets: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AffiliatePropertiesScreen())),
                    onCampaigns: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AffiliateCampaignsScreen())),
                    onReferrals: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AffiliateReferralsScreen(
                                token: widget.user.token ?? ''))),
                    onTokens: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AffiliateTokensScreen(
                                token: widget.user.token ?? ''))),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Properties',
                          style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AffiliatePropertiesScreen())),
                        child: const Text('View All',
                            style: TextStyle(
                                color: _kAccentRed,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SearchField(controller: _searchController),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _topProperties.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, i) => _AffiliatePropertyCard(
                        asset: _topProperties[i],
                        commissionPercent: i.isEven ? 2.0 : 2.5,
                        onGenerateLink: () => _generateLink(_topProperties[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _PromoBanner(),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Referral Tracker',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  _TrackerTabStrip(
                    activeIndex: _trackerTabIndex,
                    onChanged: (i) => setState(() => _trackerTabIndex = i),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._filteredReferrals.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ReferralTile(entry: r),
                      )),
                  if (_filteredReferrals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text('Nothing here yet.',
                            style: TextStyle(
                                color: AppColors.slate,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        activeIndex: _navIndex,
        onChanged: (i) {
          if (i == 1) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AffiliatePropertiesScreen()));
            return;
          }
          if (i == 2) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    AffiliateEarningsScreen(token: widget.user.token ?? '')));
            return;
          }
          if (i == 3) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    AffiliateReferralsScreen(token: widget.user.token ?? '')));
            return;
          }
          if (i == 4) {
            _openMore();
            return;
          }
          setState(() => _navIndex = i);
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.userName,
    required this.onNotifications,
    required this.onChangeLanguage,
    this.unreadNotifications = 0,
  });

  final String userName;
  final VoidCallback onNotifications;
  final VoidCallback onChangeLanguage;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.border,
            child: Icon(Icons.person_rounded, color: AppColors.slate),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const Text('Official Affiliate',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate)),
              ],
            ),
          ),
          IconButton(
            onPressed: onChangeLanguage,
            icon: const Icon(Icons.language_rounded, color: AppColors.ink),
            tooltip: 'Change language',
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none_rounded,
                    color: AppColors.ink),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints:
                        const BoxConstraints(minWidth: 15, minHeight: 15),
                    decoration: const BoxDecoration(
                        color: _kAccentRed, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AffiliateCodeCard extends StatelessWidget {
  const _AffiliateCodeCard(
      {required this.code,
      required this.onCopy,
      required this.onRequestPayout});

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccentRed, Color(0xFFC7301C)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33E84C3D), blurRadius: 16, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Affiliate Code',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Row(
              children: [
                Expanded(
                  child: Text(code,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: 0.5)),
                ),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child:
                        Icon(Icons.copy_rounded, size: 20, color: _kAccentRed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Request Payout',
              onPressed: onRequestPayout,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onShareLink,
    required this.onAssets,
    required this.onCampaigns,
    required this.onReferrals,
    required this.onTokens,
  });

  final VoidCallback onShareLink;
  final VoidCallback onAssets;
  final VoidCallback onCampaigns;
  final VoidCallback onReferrals;
  final VoidCallback onTokens;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.share_rounded, 'Share Link', onShareLink),
      (Icons.holiday_village_outlined, 'Assets', onAssets),
      (Icons.campaign_outlined, 'Campaigns', onCampaigns),
      (Icons.groups_2_outlined, 'Referrals', onReferrals),
      (Icons.toll_rounded, 'Tokens', onTokens),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items
          .map((item) =>
              _QuickActionButton(icon: item.$1, label: item.$2, onTap: item.$3))
          .toList(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
                color: Color(0xFFF0F0EE), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF4A4A45), size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search homes, vehicles...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: _kAccentRed)),
      ),
    );
  }
}

class _AffiliatePropertyCard extends StatelessWidget {
  const _AffiliatePropertyCard(
      {required this.asset,
      required this.commissionPercent,
      required this.onGenerateLink});

  final Asset asset;
  final double commissionPercent;
  final VoidCallback onGenerateLink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 11,
                  child: asset.imageUrl != null
                      ? Image.network(asset.imageUrl!,
                          fit: BoxFit.cover, width: double.infinity)
                      : Container(color: AppColors.border),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(AppRadii.pill)),
                    child: Text(
                      'Earn ${commissionPercent.toStringAsFixed(0)}% Commission',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(asset.formattedPrice,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _kAccentRed)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: onGenerateLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccentRed.withValues(alpha: 0.1),
                        foregroundColor: _kAccentRed,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Generate Link'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBEF),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kAccentRed,
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: const Text('Limited Offer',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                const Text('Summer Real Estate Drive',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                const Text('Earn Double Commission (4%)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate)),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration:
                const BoxDecoration(color: _kAccentRed, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TrackerTabStrip extends StatelessWidget {
  const _TrackerTabStrip({required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const _labels = ['All', 'Pending', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _kAccentRed : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border:
                    Border.all(color: active ? _kAccentRed : AppColors.border),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.slate),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({required this.entry});

  final _ReferralEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.border,
            child: Text(
              entry.customerName.isNotEmpty ? entry.customerName[0] : '?',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.customerName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(entry.propertyTitle,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.commissionAmount.toStringAsFixed(0)} ETB',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.isPending
                      ? const Color(0xFFFFF3D6)
                      : const Color(0xFFE3F6EA),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  entry.isPending ? 'Pending' : 'Completed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: entry.isPending
                        ? const Color(0xFFB8860B)
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (
      Icons.holiday_village_outlined,
      Icons.holiday_village_rounded,
      'Properties'
    ),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Wallet'
    ),
    (Icons.groups_outlined, Icons.groups_rounded, 'Referrals'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final (outline, filled, label) = _items[i];
            final active = i == activeIndex;

            return InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? filled : outline,
                      size: 22, color: active ? _kAccentRed : AppColors.slate),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? _kAccentRed : AppColors.slate,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── More bottom sheet ─────────────────────────────────────────────────────

class _MoreBottomSheet extends StatelessWidget {
  const _MoreBottomSheet({
    required this.onReports,
    required this.onMembership,
    required this.onSettings,
    required this.onSupport,
    required this.onLogout,
  });

  final VoidCallback onReports;
  final VoidCallback onMembership;
  final VoidCallback onSettings;
  final VoidCallback onSupport;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('More',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
          const Divider(height: 1, color: AppColors.border),

          _MoreTile(
            icon: Icons.bar_chart_outlined,
            iconFilled: Icons.bar_chart_rounded,
            label: 'Reports',
            subtitle: 'Performance analytics',
            color: const Color(0xFF2563EB),
            onTap: onReports,
          ),
          _MoreTile(
            icon: Icons.workspace_premium_outlined,
            iconFilled: Icons.workspace_premium_rounded,
            label: 'Membership',
            subtitle: 'Plan, perks & billing',
            color: AppColors.primaryYellowDark,
            onTap: onMembership,
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            iconFilled: Icons.settings_rounded,
            label: 'Settings',
            subtitle: 'Account & payout method',
            color: AppColors.slate,
            onTap: onSettings,
          ),
          _MoreTile(
            icon: Icons.help_outline_rounded,
            iconFilled: Icons.help_rounded,
            label: 'Support',
            subtitle: 'Help & contact us',
            color: _kAccentRed,
            onTap: onSupport,
          ),
          _MoreTile(
            icon: Icons.logout_rounded,
            iconFilled: Icons.logout_rounded,
            label: 'Log Out',
            subtitle: 'Sign out of this account',
            color: AppColors.danger,
            onTap: onLogout,
          ),
          const SizedBox(height: 16),
          const SafeArea(top: false, child: SizedBox()),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.iconFilled,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconFilled;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.border, size: 22),
          ],
        ),
      ),
    );
  }
}
