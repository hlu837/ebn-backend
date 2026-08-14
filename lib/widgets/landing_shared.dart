import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';

/// Breakpoint helpers shared by the landing page and its spun-off pages.
class LandingBreakpoints {
  static bool isMobile(BuildContext c) => MediaQuery.of(c).size.width < 640;
  static bool isDesktop(BuildContext c) => MediaQuery.of(c).size.width >= 1024;
}

class MaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  const MaxWidth({super.key, required this.child, this.maxWidth = 1200, this.padding = const EdgeInsets.symmetric(horizontal: 24)});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final EdgeInsets padding;
  final double fontSize;
  final VoidCallback? onTap;
  const GoldButton({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.fontSize = 15,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: LandingColors.gold,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: LandingColors.goldFg, fontWeight: FontWeight.w600, fontSize: fontSize)),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(trailing, size: 16, color: LandingColors.goldFg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Color eyebrowColor;
  final Color titleColor;
  final Color lineColor;
  const SectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.eyebrowColor = LandingColors.muted,
    this.titleColor = LandingColors.foreground,
    this.lineColor = LandingColors.border,
  });
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 640;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 1, width: wide ? 64 : 32, color: lineColor),
        const SizedBox(width: 16),
        Column(
          children: [
            Text(eyebrow.toUpperCase(),
                style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: eyebrowColor, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: wide ? 28 : 24, color: titleColor, fontWeight: FontWeight.w600, height: 1.2)),
          ],
        ),
        const SizedBox(width: 16),
        Container(height: 1, width: wide ? 64 : 32, color: lineColor),
      ],
    );
  }
}

/// Picks a column count from a width breakpoints map and lays items out
/// in a wrap so every section can be responsive without a GridView.
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(int i) itemBuilder;
  final double gap;
  final Map<int, int> breakpoints;

  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.breakpoints,
    this.gap = 16,
  });

  int _cols(double width) {
    final sorted = breakpoints.keys.toList()..sort();
    int cols = breakpoints[sorted.first] ?? 1;
    for (final bp in sorted) {
      if (width >= bp) cols = breakpoints[bp]!;
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _cols(constraints.maxWidth);
        final totalGap = gap * (cols - 1);
        final tileWidth = (constraints.maxWidth - totalGap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(itemCount, (i) {
            return SizedBox(width: tileWidth, child: itemBuilder(i));
          }),
        );
      },
    );
  }
}
