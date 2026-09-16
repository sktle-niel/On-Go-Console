import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console_backend/console_backend.dart';
import 'package:on_go_console_backend/local/local_rank_policy_service.dart';
import 'package:on_go_console/src/features/admin/admin_ranks_page.dart';
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
  late LocalRankPolicyService ranks;

  /// Built inside each test, not in setUp: streams created outside the test's
  /// zone do not deliver while it runs.
  Future<void> open(WidgetTester tester) async {
    ranks = LocalRankPolicyService(persist: false);
    ConsoleBackend.configure(rankPolicy: ranks);
    addTearDown(ConsoleBackend.debugReset);
    final signedIn = await ConsoleSession.instance.signIn('admin', 'x');
    expect(signedIn.isSuccess, isTrue);
    addTearDown(ConsoleSession.instance.signOut);

    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_at(_desktop, const AdminRanksPage()));
    await tester.pump();
  }

  Finder field(String label, int index) => find.widgetWithText(TextField, label).at(index);

  Future<void> save(WidgetTester tester) async {
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save changes'));
    expect(button.onPressed, isNotNull, reason: 'there are unsaved changes');
    button.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('lists the five ranks in order with their defaults', (tester) async {
    await open(tester);

    expect(find.text('x1 · Starting rank'), findsOneWidget);
    expect(find.text('x1.25 · 10 jobs · 5 reviews · 3.5★'), findsOneWidget);
    expect(find.text('x3 · 150 jobs · 80 reviews · 4.6★'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Points multiplier'), findsNWidgets(5));
    expect(find.widgetWithText(TextField, 'Completed jobs'), findsNWidgets(4),
        reason: 'Iron is the starting rank and asks for nothing');
    expect(find.textContaining('Ranks are not stored by the On Go API yet'), findsOneWidget);

    final titles = [for (final rank in MechanicRank.values) tester.getTopLeft(find.text(rank.label)).dy];
    expect(titles, [...titles]..sort(), reason: 'Iron, Bronze, Silver, Gold, Platinum');
  });

  testWidgets('the admin changes a multiplier and a requirement', (tester) async {
    await open(tester);

    await tester.enterText(field('Points multiplier', MechanicRank.gold.index), '2.5');
    await tester.enterText(field('Completed jobs', MechanicRank.gold.index - 1), '60');
    await save(tester);

    final saved = await ranks.fetch();
    expect(saved.gold.multiplier, 2.5);
    expect(saved.gold.requirement.completedJobs, 60);
    expect(saved.platinum, RankPolicy.defaults.platinum);
    expect(find.text('x2.5 · 60 jobs · 40 reviews · 4.3★'), findsOneWidget);
  });

  testWidgets('a multiplier above x3 is refused with the reason', (tester) async {
    await open(tester);

    await tester.enterText(field('Points multiplier', MechanicRank.platinum.index), '3.5');
    await save(tester);

    expect(find.textContaining('Platinum: the multiplier must be between x1 and x3'), findsOneWidget);
    expect(await ranks.fetch(), RankPolicy.defaults);
  });
}
