import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';

/// Every address in the console.
///
/// A website has URLs, and that is a real structural difference from the
/// mobile app this replaced: a moderator can bookmark the queue, an admin can
/// send someone a link to the audit log, and the browser's Back button works.
/// So navigation here is named routes rather than a tab index.
class ConsoleRoutes {
  ConsoleRoutes._();

  static const String signIn = '/sign-in';

  static const String adminOverview = '/admin';
  static const String adminModerators = '/admin/moderators';
  static const String adminAddModerator = '/admin/moderators/new';
  static const String adminEscalations = '/admin/escalations';
  static const String adminAudit = '/admin/audit';
  static const String adminIncome = '/admin/income';
  static const String adminPoints = '/admin/points';
  static const String adminRanks = '/admin/ranks';
  static const String adminLeaderboard = '/admin/leaderboard';
  static const String adminPerformance = '/admin/performance';
  static const String adminSettings = '/admin/settings';

  static const String moderatorQueue = '/moderator';
  static const String moderatorHistory = '/moderator/history';
  static const String moderatorAccounts = '/moderator/accounts';
  static const String moderatorProfile = '/moderator/profile';
  static const String moderatorSettings = '/moderator/settings';

  /// Reached from either Settings screen.
  static const String appearance = '/settings/appearance';
  static const String background = '/settings/background';

  /// Where a role lands after signing in.
  static String homeFor(UserRole role) =>
      role == UserRole.admin ? adminOverview : moderatorQueue;
}

/// Where a destination appears on a phone.
///
/// On a tablet or a desktop the rail lists everything, so this changes
/// nothing there. On a phone it decides which five sit in the bottom bar and
/// which are reached from the drawer or the bell — the split the Admin and
/// Moderator panels had before they moved to the web.
enum ConsolePlacement {
  /// In the phone's bottom navigation bar.
  bottomNav,

  /// In the phone's drawer.
  drawer,

  /// Behind the app bar's notification bell.
  bell,
}

/// One entry in the navigation rail.
class ConsoleDestination {
  final String route;
  final String label;
  final IconData icon;

  /// A one-line description, shown as the page's subtitle in the top bar on a
  /// tablet or desktop.
  final String blurb;

  /// Where this sits on a phone.
  final ConsolePlacement placement;

  /// What the phone's bottom bar calls this.
  ///
  /// A bar item on a 375-point screen gets about 70 points, so the bar uses
  /// the same short names the original Admin panel did — 'Mods', 'Add Mod',
  /// 'Audit'. Defaults to [label] for the destinations that already fit.
  final String? _shortLabel;

  const ConsoleDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.blurb,
    this.placement = ConsolePlacement.bottomNav,
    String? shortLabel,
  }) : _shortLabel = shortLabel;

  String get shortLabel => _shortLabel ?? label;
}

/// The rail's contents, per role.
///
/// Admin and Moderator get genuinely different navigation — they are different
/// jobs — which is the other half of why they are separate roles rather than
/// one screen with things hidden.
class ConsoleNavigation {
  ConsoleNavigation._();

  static const List<ConsoleDestination> admin = [
    ConsoleDestination(
      route: ConsoleRoutes.adminOverview,
      label: 'Overview',
      icon: Icons.monitor_heart_outlined,
      blurb: 'Platform health at a glance',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminModerators,
      label: 'Moderators',
      shortLabel: 'Mods',
      icon: Icons.shield_outlined,
      blurb: 'The people reviewing accounts',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminAddModerator,
      label: 'Add Moderator',
      shortLabel: 'Add',
      icon: Icons.person_add_alt,
      blurb: 'Create a console account',
    ),
    // Reached from the bell on a phone, exactly as the Admin panel's
    // Notifications screen was.
    ConsoleDestination(
      route: ConsoleRoutes.adminEscalations,
      label: 'Notifications',
      shortLabel: 'Alerts',
      icon: Icons.notifications_none,
      blurb: 'Moderator activity and requests needing you',
      placement: ConsolePlacement.bell,
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminAudit,
      label: 'Audit Log',
      shortLabel: 'Audit',
      icon: Icons.history,
      blurb: 'Every change to the moderator roster',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminIncome,
      label: 'Income',
      icon: Icons.bar_chart,
      blurb: 'Platform revenue reported by the mobile app',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminPoints,
      label: 'Urgency Levels',
      shortLabel: 'Urgency',
      icon: Icons.tune,
      blurb: 'Points, additional charge and completion time per urgency',
      placement: ConsolePlacement.drawer,
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminRanks,
      label: 'Mechanic Ranks',
      shortLabel: 'Ranks',
      icon: Icons.military_tech_outlined,
      blurb: 'Rank requirements and points multipliers',
      placement: ConsolePlacement.drawer,
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminLeaderboard,
      label: 'Leaderboard',
      icon: Icons.emoji_events_outlined,
      blurb: 'Public switch, seasons, scoring and seasonal multipliers',
      placement: ConsolePlacement.drawer,
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminPerformance,
      label: 'Performance',
      icon: Icons.fact_check_outlined,
      blurb: 'Standings preview, evaluations, point transactions and flags',
      placement: ConsolePlacement.drawer,
    ),
    ConsoleDestination(
      route: ConsoleRoutes.adminSettings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      blurb: 'Console and platform preferences',
      placement: ConsolePlacement.drawer,
    ),
  ];

  static const List<ConsoleDestination> moderator = [
    ConsoleDestination(
      route: ConsoleRoutes.moderatorQueue,
      label: 'Queue',
      icon: Icons.watch_later_outlined,
      blurb: 'Accounts waiting on a decision',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.moderatorHistory,
      label: 'History',
      icon: Icons.history,
      blurb: 'Everything already decided',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.moderatorAccounts,
      label: 'Accounts',
      icon: Icons.people_outline,
      blurb: 'Approved accounts on the platform',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.moderatorProfile,
      label: 'Profile',
      icon: Icons.person_outline,
      blurb: 'Your account and permissions',
    ),
    ConsoleDestination(
      route: ConsoleRoutes.moderatorSettings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      blurb: 'Console preferences and security',
      placement: ConsolePlacement.drawer,
    ),
  ];

  /// Everything this role can reach. What the rail lists on a tablet or a
  /// desktop, and the full set a phone splits three ways.
  static List<ConsoleDestination> forRole(UserRole role) =>
      role == UserRole.admin ? admin : moderator;

  /// The phone's bottom bar: five for Admin, four for Moderator, in the order
  /// the original panels had them.
  static List<ConsoleDestination> bottomNavFor(UserRole role) => forRole(role)
      .where((d) => d.placement == ConsolePlacement.bottomNav)
      .toList(growable: false);

  /// What the phone's drawer lists below the account header.
  static List<ConsoleDestination> drawerFor(UserRole role) => forRole(role)
      .where((d) => d.placement == ConsolePlacement.drawer)
      .toList(growable: false);

  /// Where the app bar's bell goes, or null when this role's bell only counts.
  static ConsoleDestination? bellFor(UserRole role) {
    for (final destination in forRole(role)) {
      if (destination.placement == ConsolePlacement.bell) return destination;
    }
    return null;
  }

  /// The destination a route belongs to, for the rail's selected state and the
  /// top bar's title. Sub-pages fall back to null and supply their own title.
  static ConsoleDestination? find(UserRole role, String? route) {
    for (final destination in forRole(role)) {
      if (destination.route == route) return destination;
    }
    return null;
  }
}
