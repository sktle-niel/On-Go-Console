import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console/src/app/console_routes.dart';
import 'package:on_go_console/src/app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import 'package:on_go_console/src/session/console_session.dart';
import 'package:on_go_console/src/theme/console_theme.dart';

/// The console's responsive behaviour, pinned.
///
/// These exist because the layout rules are the kind of thing that regresses
/// silently: a page keeps compiling and keeps working on the developer's own
/// 1440-point screen while quietly becoming unusable on a phone. Asserting the
/// arrangement at each device class is the only way that gets caught.

/// Wraps [child] in a window of exactly [size].
Widget _at(Size size, Widget child) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: ConsoleTheme.of(AppThemes.all.first),
      home: Builder(
        builder: (context) => SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

const Size _phone = Size(390, 844);
const Size _tablet = Size(900, 1200);
const Size _wideTablet = Size(1000, 1200);
const Size _narrowTablet = Size(700, 1000);
const Size _desktop = Size(1440, 900);

void main() {
  group('ConsoleLayout classification', () {
    test('sorts widths into the three device classes', () {
      expect(ConsoleLayout.fromSize(_phone).formFactor, ConsoleFormFactor.phone);
      expect(ConsoleLayout.fromSize(_tablet).formFactor, ConsoleFormFactor.tablet);
      expect(ConsoleLayout.fromSize(_desktop).formFactor, ConsoleFormFactor.desktop);
    });

    test('boundaries land on the wider class', () {
      expect(
        ConsoleLayout.fromSize(const Size(ConsoleLayout.tabletMin, 800)).formFactor,
        ConsoleFormFactor.tablet,
      );
      expect(
        ConsoleLayout.fromSize(const Size(ConsoleLayout.desktopMin, 800)).formFactor,
        ConsoleFormFactor.desktop,
      );
      expect(
        ConsoleLayout.fromSize(const Size(ConsoleLayout.tabletMin - 1, 800)).formFactor,
        ConsoleFormFactor.phone,
      );
    });

    test('picks one navigation arrangement per width, never two', () {
      for (final size in [_phone, _narrowTablet, _tablet, _wideTablet, _desktop]) {
        final layout = ConsoleLayout.fromSize(size);
        final chosen = [layout.railPinned, layout.railCollapsed, layout.railInDrawer]
            .where((on) => on)
            .length;
        expect(chosen, 1, reason: 'exactly one rail arrangement at ${size.width}');
      }
    });

    test('a desktop pins the rail; a phone puts it in the drawer', () {
      expect(ConsoleLayout.fromSize(_desktop).railPinned, isTrue);
      expect(ConsoleLayout.fromSize(_phone).railInDrawer, isTrue);
      expect(ConsoleLayout.fromSize(_phone).showsBottomNav, isTrue);
      expect(ConsoleLayout.fromSize(_desktop).showsBottomNav, isFalse);
    });

    test('a tablet gets the icon rail once there is room for one', () {
      expect(ConsoleLayout.fromSize(_wideTablet).railCollapsed, isTrue);
      expect(ConsoleLayout.fromSize(_narrowTablet).railInDrawer, isTrue);
    });

    test('stat columns narrow with the device, but never below two', () {
      expect(ConsoleLayout.fromSize(_desktop).statColumns, 4);
      expect(ConsoleLayout.fromSize(_tablet).statColumns, 2);
      // The Admin panel's four figures read as a 2x2 block on a phone.
      expect(ConsoleLayout.fromSize(_phone).statColumns, 2);
    });

    test('only a phone turns table rows into cards', () {
      expect(ConsoleLayout.fromSize(_phone).stacksTableRows, isTrue);
      expect(ConsoleLayout.fromSize(_tablet).stacksTableRows, isFalse);
      expect(ConsoleLayout.fromSize(_desktop).stacksTableRows, isFalse);
    });

    test('gutters and card padding shrink on smaller devices', () {
      final phone = ConsoleLayout.fromSize(_phone);
      final tablet = ConsoleLayout.fromSize(_tablet);
      final desktop = ConsoleLayout.fromSize(_desktop);

      expect(phone.gutter, lessThan(tablet.gutter));
      expect(tablet.gutter, lessThan(desktop.gutter));
      expect(phone.cardPadding, lessThan(desktop.cardPadding));
    });

    test('a dialog never asks for more width than the window has', () {
      final phone = ConsoleLayout.fromSize(_phone);
      expect(phone.dialogWidth(520), lessThan(_phone.width));
      expect(phone.dialogWidth(520), greaterThan(0));

      // A desktop gets exactly what it asked for.
      expect(ConsoleLayout.fromSize(_desktop).dialogWidth(520), 520);
    });

    test('month labels thin out on a phone and stay whole elsewhere', () {
      expect(ConsoleLayout.fromSize(_phone).monthLabelStride(12), greaterThan(1));
      expect(ConsoleLayout.fromSize(_phone).monthLabelStride(4), 1);
      expect(ConsoleLayout.fromSize(_desktop).monthLabelStride(12), 1);
    });

    test('every destination stays reachable on a phone', () {
      // The bar is a shortcut, not a smaller product: whatever it cannot hold
      // is in the drawer or behind the bell, and nothing is dropped.
      for (final role in [UserRole.admin, UserRole.moderator]) {
        final all = ConsoleNavigation.forRole(role).map((d) => d.route).toSet();
        final reachable = {
          ...ConsoleNavigation.bottomNavFor(role).map((d) => d.route),
          ...ConsoleNavigation.drawerFor(role).map((d) => d.route),
          ?ConsoleNavigation.bellFor(role)?.route,
        };
        expect(reachable, all, reason: '${role.label} loses a destination');
      }
    });

    test('the phone bar never exceeds five destinations', () {
      for (final role in [UserRole.admin, UserRole.moderator]) {
        expect(
          ConsoleNavigation.bottomNavFor(role).length,
          lessThanOrEqualTo(5),
          reason: '${role.label} would crowd the bar',
        );
      }
    });
  });

  group('ConsoleShell arrangement', () {
    setUp(() async {
      await ConsoleSession.instance.signOut();
    });

    /// Signs in as the built-in admin, which is what the shell reads to decide
    /// which destination list to show.
    Future<void> signInAsAdmin() async {
      final result = await ConsoleSession.instance.signIn('admin', 'x');
      expect(result.isSuccess, isTrue);
    }

    testWidgets('desktop pins the rail and shows no bottom bar', (tester) async {
      await signInAsAdmin();
      tester.view.physicalSize = _desktop;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _at(_desktop, const ConsoleShell(child: SizedBox.shrink())),
      );
      await tester.pump();

      expect(find.byType(NavigationBar), findsNothing);
      // The full rail renders its labels; the icon rail does not.
      expect(find.text('Add Moderator'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('phone wears the app\'s own chrome', (tester) async {
      await signInAsAdmin();
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _at(_phone, const ConsoleShell(child: SizedBox.shrink())),
      );
      await tester.pump();

      // The same widgets the Client and Mechanic shells use, from
      // package:on_go_design — not a lookalike built here.
      expect(find.byType(OnGoBottomNav), findsOneWidget);
      expect(find.byType(OnGoAppBar), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);

      // The wordmark and the panel name, as the Admin panel had them.
      expect(find.text('On Go'), findsOneWidget);
      expect(find.text('Admin Panel'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('the phone bottom bar carries the Admin panel\'s five tabs',
        (tester) async {
      await signInAsAdmin();
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _at(_phone, const ConsoleShell(child: SizedBox.shrink())),
      );
      await tester.pump();

      final bar = tester.widget<OnGoBottomNav>(find.byType(OnGoBottomNav));
      expect(
        bar.items.map((item) => item.label).toList(),
        ['Overview', 'Mods', 'Add', 'Audit', 'Income'],
      );

      // Notifications sits behind the bell, and Urgency Levels, Mechanic Ranks
      // and Settings in the drawer, so none of them takes a slot — and none is
      // unreachable.
      expect(ConsoleNavigation.bellFor(UserRole.admin)?.route,
          ConsoleRoutes.adminEscalations);
      expect(
        ConsoleNavigation.drawerFor(UserRole.admin).map((d) => d.route).toList(),
        [
          ConsoleRoutes.adminPoints,
          ConsoleRoutes.adminRanks,
          ConsoleRoutes.adminLeaderboard,
          ConsoleRoutes.adminPerformance,
          ConsoleRoutes.adminSettings,
        ],
      );
    });

    testWidgets('tablet shows the icon rail, no labels, no bottom bar',
        (tester) async {
      await signInAsAdmin();
      tester.view.physicalSize = _wideTablet;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _at(_wideTablet, const ConsoleShell(child: SizedBox.shrink())),
      );
      await tester.pump();

      expect(find.byType(OnGoBottomNav), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);
      // Icons only — the label lives in a tooltip at this size.
      expect(find.text('Add Moderator'), findsNothing);
      expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
    });

    testWidgets('a moderator gets the same arrangement as an admin',
        (tester) async {
      // Create a moderator, then sign in as them.
      await signInAsAdmin();
      await ConsoleBackend.instance.moderators.createModerator(
        const CreateModeratorRequest(
          name: 'Vince Juno',
          email: 'vince@example.com',
          temporaryPassword: 'secret123',
        ),
      );
      final signedIn =
          await ConsoleSession.instance.signIn('vince@example.com', 'secret123');
      expect(signedIn.isSuccess, isTrue);
      expect(ConsoleSession.instance.isModerator, isTrue);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _at(_phone, const ConsoleShell(child: SizedBox.shrink())),
      );
      await tester.pump();

      expect(find.byType(OnGoBottomNav), findsOneWidget);
      expect(find.byType(OnGoAppBar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Moderator Panel'), findsOneWidget);

      final bar = tester.widget<OnGoBottomNav>(find.byType(OnGoBottomNav));
      expect(
        bar.items.map((item) => item.label).toList(),
        ['Queue', 'History', 'Accounts', 'Profile'],
      );
      expect(
        ConsoleNavigation.drawerFor(UserRole.moderator)
            .map((d) => d.route)
            .toList(),
        [ConsoleRoutes.moderatorSettings],
      );
    });
  });
}
