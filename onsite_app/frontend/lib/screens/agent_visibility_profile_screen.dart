import 'package:flutter/material.dart';

import '../models/agent_account.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/broker.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_drawer.dart' show AgentTier, AgentTierX;
import 'broker_profile_screen.dart';

/// Lets the agent edit how they appear to customers — bio, city,
/// specialties — see their ratings/reviews, boost their visibility in
/// search, and preview their public profile exactly as a visitor sees it.
/// Backed by `GET/PATCH /api/agents/:id/profile` and
/// `POST /api/agents/:id/profile/boost`.
class AgentVisibilityProfileScreen extends StatefulWidget {
  const AgentVisibilityProfileScreen({super.key, required this.user, required this.tier});

  final AppUser user;
  final AgentTier tier;

  @override
  State<AgentVisibilityProfileScreen> createState() => _AgentVisibilityProfileScreenState();
}

class _AgentVisibilityProfileScreenState extends State<AgentVisibilityProfileScreen> {
  final _service = AgentService();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final Set<AssetCategorySlug> _specialties = {};

  bool _loading = true;
  String? _loadError;
  bool _dirty = false;
  bool _boosted = false;
  int _reviewCount = 0;
  double _avgRating = 0;
  List<AgentReview> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _service.getProfile(widget.user.id, token: widget.user.token);
      if (!mounted) return;
      setState(() {
        _bio.text = profile.bio;
        _city.text = profile.city;
        _specialties
          ..clear()
          ..addAll(profile.specialties.map(_slugFromString).whereType<AssetCategorySlug>());
        _boosted = profile.boosted;
        _reviewCount = profile.reviewCount;
        _avgRating = profile.avgRating;
        _reviews = profile.reviews;
        _loading = false;
      });
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  static AssetCategorySlug? _slugFromString(String value) {
    for (final c in AssetCategorySlug.values) {
      if (c.name == value) return c;
    }
    return null;
  }

  @override
  void dispose() {
    _bio.dispose();
    _city.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    try {
      await _service.updateProfile(
        widget.user.id,
        bio: _bio.text.trim(),
        city: _city.text.trim(),
        specialties: _specialties.map((s) => s.name).toList(),
        token: widget.user.token ?? '',
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  BrokerTier get _brokerTier => switch (widget.tier) {
        AgentTier.bronze => BrokerTier.bronze,
        AgentTier.silver => BrokerTier.silver,
        AgentTier.gold => BrokerTier.gold,
        AgentTier.diamond => BrokerTier.diamond,
      };

  void _previewAsCustomer() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrokerProfileScreen(
        broker: Broker(
          id: widget.user.id,
          name: widget.user.fullName,
          company: widget.user.agencyOrLicense ?? 'Independent Broker',
          city: _city.text.trim().isEmpty ? 'Addis Ababa' : _city.text.trim(),
          phone: widget.user.phone,
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          rating: _avgRating,
          specialties: _specialties.toList(),
          tier: _brokerTier,
          latitude: 9.0192,
          longitude: 38.7525,
        ),
      ),
    ));
  }

  void _openBoostSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _BoostSheet(
        currentlyBoosted: _boosted,
        onConfirm: () async {
          Navigator.of(sheetContext).pop();
          try {
            await _service.boostProfile(widget.user.id, token: widget.user.token ?? '');
            if (!mounted) return;
            setState(() => _boosted = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your profile is now boosted for 7 days.')));
          } on AgentServiceException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Visibility & Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _dirty ? _save : null,
            child: Text('Save', style: TextStyle(fontWeight: FontWeight.w800, color: _dirty ? AppColors.primaryYellow : Colors.white38)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.border,
                            child: Text(widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: AppColors.ink,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo upload coming soon.'))),
                                child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(child: Text(widget.user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink))),
                    const SizedBox(height: 4),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.tier.icon, size: 14, color: widget.tier.color),
                          const SizedBox(width: 4),
                          Text(widget.tier.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: widget.tier.color)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    const Text('Public Bio', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(controller: _bio, maxLines: 4, onChanged: (_) => _markDirty(), decoration: const InputDecoration(hintText: 'Tell customers what you specialize in...')),
                    const SizedBox(height: AppSpacing.md),

                    const Text('City', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(controller: _city, onChanged: (_) => _markDirty(), decoration: const InputDecoration(hintText: 'e.g. Addis Ababa')),
                    const SizedBox(height: AppSpacing.md),

                    const Text('Specialties', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AssetCategorySlug.values.map((c) {
                        final selected = _specialties.contains(c);
                        return FilterChip(
                          label: Text(c.label),
                          selected: selected,
                          onSelected: (v) {
                            setState(() => v ? _specialties.add(c) : _specialties.remove(c));
                            _markDirty();
                          },
                          selectedColor: AppColors.ink,
                          labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink),
                          backgroundColor: AppColors.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill), side: BorderSide(color: selected ? AppColors.ink : AppColors.border)),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      children: [
                        const Expanded(child: Text('Ratings & Reviews', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink))),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 17, color: AppColors.primaryYellow),
                          const SizedBox(width: 3),
                          Text('${_avgRating.toStringAsFixed(1)} ($_reviewCount)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text('No reviews yet.', style: TextStyle(fontSize: 13, color: AppColors.slate)),
                      ),
                    for (final r in _reviews) ...[
                      _ReviewTile(review: r),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.sm),

                    _BoostCard(boosted: _boosted, onTap: _openBoostSheet),
                    const SizedBox(height: AppSpacing.md),

                    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _previewAsCustomer, icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('Preview as a customer'))),
                  ],
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final AgentReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(review.reviewerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink))),
              Row(children: List.generate(5, (i) => Icon(i < review.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 14, color: AppColors.primaryYellow))),
            ],
          ),
          const SizedBox(height: 5),
          Text(review.quote, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
        ],
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  const _BoostCard({required this.boosted, required this.onTap});
  final bool boosted;
  final VoidCallback onTap;

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
                Text(boosted ? 'PROFILE BOOSTED' : 'VISIBILITY', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryYellow, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                  boosted ? 'Active for the next 7 days' : 'Appear higher in search results',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(AppRadii.pill)),
                    child: Text(boosted ? 'Extend boost' : 'Boost my profile', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: AppColors.primaryYellow, size: 42),
        ],
      ),
    );
  }
}

class _BoostSheet extends StatelessWidget {
  const _BoostSheet({required this.currentlyBoosted, required this.onConfirm});
  final bool currentlyBoosted;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Text('Boost Your Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Boosted profiles appear higher in "Find Brokers" search results and get a highlighted badge.', style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.primaryYellow, width: 1.4)),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('7-Day Boost', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        SizedBox(height: 2),
                        Text('Priority placement for a week', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                      ],
                    ),
                  ),
                  Text('ETB 350', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onConfirm, child: Text(currentlyBoosted ? 'Extend Boost' : 'Confirm Boost')),
          ],
        ),
      ),
    );
  }
}
