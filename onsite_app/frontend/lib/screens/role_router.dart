import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../models/user_role.dart';
import 'admin_home_screen.dart';
import 'affiliater_home_screen.dart';
import 'agent_home_screen.dart';
import 'customer_home_screen.dart';
import 'investor_home_screen.dart';

/// The one place that knows "this role → this workspace". Both the Login
/// page's smart router and the Sign-Up flow's post-registration redirect
/// call this, so there's a single source of truth for where each of the
/// four (five, counting Admin) roles land:
///
///   Visitor      → Standard Marketplace Feed   (CustomerHomeScreen)
///   Affiliater   → Affiliate Dashboard          (AffiliaterHomeScreen)
///   Agent/Broker → Listing Manager & Client Tracker (AgentHomeScreen)
///   Investor     → Portfolio Portal + Sell-a-property (InvestorHomeScreen)
///   Admin        → Approvals & Ops Console      (AdminHomeScreen)
Widget dashboardForRole(UserRole role, AppUser user) {
  return switch (role) {
    UserRole.user => CustomerHomeScreen(user: user),
    UserRole.agent => AgentHomeScreen(user: user),
    UserRole.admin => AdminHomeScreen(user: user),
    UserRole.investor => InvestorHomeScreen(user: user),
    UserRole.affiliater => AffiliaterHomeScreen(user: user),
  };
}
