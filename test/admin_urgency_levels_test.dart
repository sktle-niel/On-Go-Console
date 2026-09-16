import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console_backend/console_backend.dart';
import 'package:on_go_console_backend/local/local_points_policy_service.dart';
import 'package:on_go_console_backend/local/local_urgency_policy_service.dart';
import 'package:on_go_console/src/features/admin/admin_points_page.dart';
import 'package:on_go_console/src/session/console_session.dart';
import 'package:on_go_console/src/theme/console_theme.dart';

Widget _at(Size size, Widget child) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: ConsoleTheme.of(AppThemes.all.first),
      home: Builder(
        builder: (context) => SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

const Size _desktop = Size(1440, 900);

void main() {
  late LocalUrgencyPolicyService urgency;
  late LocalPointsPolicyService points;

  /// Built inside each test, not in setUp: streams created outside the test's
  /// zone do not deliver while it runs.
  Future<void> open(WidgetTester tester) async {
    urgency = LocalUrgencyPolicyService(persist: false);
    points = LocalPointsPolicyService();
    ConsoleBackend.configure(urgencyPolicy: urgency, pointsPolicy: points);
    addTearDown(ConsoleBackend.debugReset);
    final signedIn = await ConsoleSession.instance.signIn('admin', 'x');
    expect(signedIn.isSuccess, isTrue);
    addTearDown(ConsoleSession.instance.signOut);

    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_at(_desktop, const AdminPointsPage()));
    await tester.pump();
  }

  Finder field(String label, int level) => find.widgetWithText(TextField, label).at(level);

  Future<void> save(WidgetTester tester) async {
    // Typing rebuilds the page on the next frame; read the button after it.
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save changes'));
    expect(button.onPressed, isNotNull, reason: 'there are unsaved changes');
    button.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows each level with the defaults, and says where the settings go', (tester) async {
    await open(tester);

    expect(find.text('1 pt · +₱10 · No time limit'), findsOneWidget);
    expect(find.text('3 pts · +₱50 · 3 days'), findsOneWidget);
    expect(find.text('5 pts · +₱100 · 12 hours'), findsOneWidget);
    expect(find.textContaining('not stored by the On Go API yet'), findsOneWidget);
    expect(find.textContaining('per ₱1'), findsNothing, reason: 'mechanics no longer earn per peso');
  });

  testWidgets('the admin changes points, the charge and the time completion unit', (tester) async {
    await open(tester);

    await tester.enterText(field('Points', 1), '4');
    await tester.enterText(field('Additional charge', 1), '75');

    // Normal: from None to 45 minutes, a number and a unit like an ETA.
    expect(tester.widget<TextField>(field('Time completion', 0)).enabled, isFalse,
        reason: 'no number to enter while the unit is None');
    tester
        .widget<DropdownButtonFormField<CompletionTimeUnit>>(
            find.byType(DropdownButtonFormField<CompletionTimeUnit>).first)
        .onChanged!(CompletionTimeUnit.minutes);
    await tester.pump();
    await tester.enterText(field('Time completion', 0), '45');

    await save(tester);

    final savedTerms = await urgency.fetch();
    expect(savedTerms.normal.completionTime, const CompletionTime(45, CompletionTimeUnit.minutes));
    expect(savedTerms.urgent.additionalCharge, 75);
    expect(savedTerms.emergency, UrgencyPolicy.defaults.emergency);

    final savedPoints = await points.fetch();
    expect(savedPoints.pointsFor('Urgent'), 4);
    expect(savedPoints.mechanicPerPeso, PointsPolicy.defaults.mechanicPerPeso);
    expect(find.text('4 pts · +₱75 · 3 days'), findsOneWidget);
  });

  testWidgets('an unusable time completion is refused with the reason, and nothing is saved', (tester) async {
    await open(tester);

    await tester.enterText(field('Time completion', 2), '0');
    await save(tester);

    expect(find.textContaining('Emergency: enter the completion time'), findsOneWidget);
    expect(await urgency.fetch(), UrgencyPolicy.defaults);
  });
}
