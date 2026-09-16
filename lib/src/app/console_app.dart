import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../features/admin/admin_add_moderator_page.dart';
import '../features/admin/admin_audit_page.dart';
import '../features/admin/admin_escalations_page.dart';
import '../features/admin/admin_income_page.dart';
import '../features/admin/admin_points_page.dart';
import '../features/admin/admin_leaderboard_page.dart';
import '../features/admin/admin_performance_page.dart';
import '../features/admin/admin_ranks_page.dart';
import '../features/admin/admin_moderators_page.dart';
import '../features/admin/admin_overview_page.dart';
import '../features/admin/admin_settings_page.dart';
import '../features/auth/console_sign_in_page.dart';
import '../features/moderator/moderator_accounts_page.dart';
import '../features/moderator/moderator_history_page.dart';
import '../features/moderator/moderator_profile_page.dart';
import '../features/moderator/moderator_queue_page.dart';
import '../features/moderator/moderator_settings_page.dart';
import '../features/shared/appearance_page.dart';
import '../features/shared/change_background_page.dart';
import '../session/console_session.dart';
import '../theme/console_theme.dart';
import 'console_routes.dart';

/// The console application root.
///
/// Rebuilds on a theme change the way the mobile app's root does, and resolves
/// every route through [_onGenerateRoute] so the browser's address bar, Back
/// button and bookmarks all work.
class ConsoleApp extends StatefulWidget {
  const ConsoleApp({super.key});

  @override
  State<ConsoleApp> createState() => _ConsoleAppState();
}

class _ConsoleAppState extends State<ConsoleApp> {
  /// The shared controller — the same object the mobile app drives, so Dark
  /// Mode, Dynamic Themes and the Warm Filter behave identically here.
  final _theme = ThemeController.instance;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onThemeChanged);
    ConsoleSession.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    ConsoleSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// A session the server ended — expired, revoked, the account deactivated —
  /// returns to Sign In from any page. Signing out on purpose navigates there
  /// itself.
  bool _wasSignedIn = false;

  void _onSessionChanged() {
    final signedIn = ConsoleSession.instance.isSignedIn;
    if (_wasSignedIn && !signedIn) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(ConsoleRoutes.signIn, (route) => false);
    }
    _wasSignedIn = signedIn;
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On Go Console',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.of(_theme.selected),
      initialRoute: ConsoleRoutes.signIn,
      onGenerateRoute: _onGenerateRoute,
      // The Warm Filter tints everything below MaterialApp — pages, dialogs
      // and the rail alike — in one compositing pass, exactly as the mobile
      // app applies it.
      builder: (context, child) =>
          AppWarmFilter.wrap(_theme.warmFilter, child ?? const SizedBox.shrink()),
    );
  }

  /// Resolves a route, with the session gate in front of it.
  ///
  /// Two rules, both applied here rather than inside the pages:
  ///
  /// * Nobody signed in gets the Sign In page, whatever they asked for. A
  ///   bookmarked deep link therefore lands on sign-in rather than a
  ///   half-rendered screen.
  /// * A route belonging to the other role redirects to this role's home. An
  ///   admin URL is not a moderator's to open, even by typing it.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final session = ConsoleSession.instance;
    final user = session.user;

    if (user == null) {
      return _page(const ConsoleSignInPage(), ConsoleRoutes.signIn);
    }

    final requested =
        settings.name == ConsoleRoutes.signIn ? null : settings.name;
    final route = requested ?? ConsoleRoutes.homeFor(user.role);

    if (!_allowed(user.role, route)) {
      final home = ConsoleRoutes.homeFor(user.role);
      return _page(_pageFor(home) ?? const SizedBox.shrink(), home);
    }

    final page = _pageFor(route);
    if (page == null) return _page(_NotFoundPage(route: route), route);
    return _page(page, route);
  }

  /// Whether [role] may open [route]. Shared routes are open to both.
  bool _allowed(UserRole role, String route) {
    if (route.startsWith('/settings/')) return true;
    return role == UserRole.admin
        ? route.startsWith('/admin')
        : route.startsWith('/moderator');
  }

  Widget? _pageFor(String route) => switch (route) {
        ConsoleRoutes.adminOverview => const AdminOverviewPage(),
        ConsoleRoutes.adminModerators => const AdminModeratorsPage(),
        ConsoleRoutes.adminAddModerator => const AdminAddModeratorPage(),
        ConsoleRoutes.adminEscalations => const AdminEscalationsPage(),
        ConsoleRoutes.adminAudit => const AdminAuditPage(),
        ConsoleRoutes.adminIncome => const AdminIncomePage(),
        ConsoleRoutes.adminPoints => const AdminPointsPage(),
        ConsoleRoutes.adminRanks => const AdminRanksPage(),
        ConsoleRoutes.adminLeaderboard => const AdminLeaderboardPage(),
        ConsoleRoutes.adminPerformance => const AdminPerformancePage(),
        ConsoleRoutes.adminSettings => const AdminSettingsPage(),
        ConsoleRoutes.moderatorQueue => const ModeratorQueuePage(),
        ConsoleRoutes.moderatorHistory => const ModeratorHistoryPage(),
        ConsoleRoutes.moderatorAccounts => const ModeratorAccountsPage(),
        ConsoleRoutes.moderatorProfile => const ModeratorProfilePage(),
        ConsoleRoutes.moderatorSettings => const ModeratorSettingsPage(),
        ConsoleRoutes.appearance => const AppearancePage(),
        ConsoleRoutes.background => const ChangeBackgroundPage(),
        _ => null,
      };

  /// Rail navigation replaces the page rather than stacking it, so there is no
  /// slide transition between destinations — a sidebar app should not animate
  /// like a phone. Sub-pages pushed on top keep the default.
  Route<dynamic> _page(Widget child, String name) => PageRouteBuilder<void>(
        settings: RouteSettings(name: name),
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 120),
      );
}

/// A typed URL that matches nothing.
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final home = ConsoleRoutes.homeFor(
      ConsoleSession.instance.user?.role ?? UserRole.moderator,
    );

    return Scaffold(
      backgroundColor: ConsoleColors.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_outlined, size: 34, color: ConsoleColors.textMuted),
              const SizedBox(height: 16),
              Text('Page not found', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Nothing in the console answers to $route.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamedAndRemoveUntil(context, home, (r) => false),
                child: const Text('Back to the console'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
