import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom navigation for the Investor workspace: Home / Opportunities /
/// Portfolio / Menu, plus a raised center "+" for the primary quick action
/// (Sell a property). Mirrors [AgentBottomNav] so every side of the app
/// shares the same navigation language — this replaces the old side
/// [InvestorDrawer]; everything that used to live in the drawer now lives
/// one tap away under Menu.
class InvestorBottomNav extends StatelessWidget {
  const InvestorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
    this.unreadMenuCount = 0,
  });

  /// 0 = Home, 1 = Opportunities, 2 = Portfolio, 3 = Menu.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;
  final int unreadMenuCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(icon: Icons.home_filled, label: 'Home', selected: currentIndex == 0, onTap: () => onTap(0)),
                    _NavItem(icon: Icons.explore_rounded, label: 'Opportunities', selected: currentIndex == 1, onTap: () => onTap(1)),
                    const Expanded(child: SizedBox()), // gap for the raised + button
                    _NavItem(icon: Icons.pie_chart_rounded, label: 'Portfolio', selected: currentIndex == 2, onTap: () => onTap(2)),
                    _NavItem(icon: Icons.menu_rounded, label: 'Menu', selected: currentIndex == 3, onTap: () => onTap(3), badgeCount: unreadMenuCount),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cloud, width: 4),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryYellow.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryYellow : AppColors.slate;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 15),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.card, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
