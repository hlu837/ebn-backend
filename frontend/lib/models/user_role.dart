import 'package:flutter/material.dart';

/// The account types supported by the platform demo. `user` is presented
/// to visitors as "Visitor" throughout the UI — the enum name is kept for
/// backward compatibility with the rest of the app.
enum UserRole { user, affiliater, agent, investor, admin }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
        UserRole.user => 'user',
        UserRole.affiliater => 'affiliater',
        UserRole.agent => 'agent',
        UserRole.investor => 'investor',
        UserRole.admin => 'admin',
      };

  String get label => switch (this) {
        UserRole.user => 'Visitor',
        UserRole.affiliater => 'Affiliater',
        UserRole.agent => 'Agent / Broker',
        UserRole.investor => 'Investor',
        UserRole.admin => 'Admin',
      };

  String get pitchLine => switch (this) {
        UserRole.user => 'Browse premium listings and explore the market.',
        UserRole.affiliater => 'Zero investment. Share links, complete tasks, and earn tokens.',
        UserRole.agent => 'List assets, manage clients, and close deals professionally.',
        UserRole.investor => 'Track portfolios and invest in high-yield assets.',
        UserRole.admin => 'Manage approvals, agents, and listings platform-wide.',
      };

  IconData get pitchIcon => switch (this) {
        UserRole.user => Icons.explore_rounded,
        UserRole.affiliater => Icons.share_rounded,
        UserRole.agent => Icons.badge_rounded,
        UserRole.investor => Icons.trending_up_rounded,
        UserRole.admin => Icons.admin_panel_settings_rounded,
      };

  String get signupHeadline => switch (this) {
        UserRole.user => 'Create your account',
        UserRole.affiliater => 'Join as an Affiliater',
        UserRole.agent => 'Join as an Agent / Broker',
        UserRole.investor => 'Join as an Investor',
        UserRole.admin => 'Admin account',
      };

  String get signupSubtitle => switch (this) {
        UserRole.user => 'Browse assets and request live, on-site walkthroughs.',
        UserRole.affiliater => 'Share property links, complete simple tasks, and earn tokens — zero investment required.',
        UserRole.agent => 'Go online, get dispatched, and earn from every verified visit.',
        UserRole.investor => 'Track portfolios and get early access to high-yield assets.',
        UserRole.admin => 'Admin accounts are provisioned by the team — sign in instead.',
      };

  String get signinHeadline => switch (this) {
        UserRole.user => 'Welcome back',
        UserRole.affiliater => 'Affiliater sign in',
        UserRole.agent => 'Agent sign in',
        UserRole.investor => 'Investor sign in',
        UserRole.admin => 'Admin sign in',
      };

  String get signinSubtitle => switch (this) {
        UserRole.user => 'Sign in to keep browsing and booking walkthroughs.',
        UserRole.affiliater => 'Sign in to check your token balance and referral links.',
        UserRole.agent => 'Sign in to go online and start receiving dispatches.',
        UserRole.investor => 'Sign in to view your portfolio and opportunities.',
        UserRole.admin => 'Sign in to manage approvals, agents, and listings.',
      };
}
