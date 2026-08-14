import 'package:flutter/material.dart';

/// Shared palette for the public-facing marketing pages (landing, about us,
/// contact us, FAQ). Kept separate from `theme/app_theme.dart`, which is
/// used by the authenticated in-app screens, so the two never collide.
class LandingColors {
  static const background = Color(0xFFFFFFFF); // white
  static const card       = Color(0xFFFFFDF7);
  static const foreground = Color(0xFF16130E); // near-black ink
  static const muted      = Color(0xFF6B6558);
  static const border     = Color(0xFFE7E0D2);
  static const gold       = Color(0xFFFF2636); // red accent, matches landing/visitor dashboard
  static const goldFg     = Color(0xFFFFFFFF);
  static const primary    = Color(0xFF16130E);
  static const primaryFg  = Color(0xFFF7F3EC);
}
