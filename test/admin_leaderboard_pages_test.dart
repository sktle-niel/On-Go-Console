import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console_backend/console_backend.dart';
import 'package:on_go_console_backend/local/local_leaderboard_config_service.dart';
import 'package:on_go_console_backend/local/local_performance_audit_log.dart';
import 'package:on_go_console_backend/local/local_performance_review_service.dart';
import 'package:on_go_console/src/features/admin/admin_leaderboard_page.dart';
import 'package:on_go_console/src/features/admin/admin_performance_page.dart';
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
const Size _phone = Size(390, 844);

void main() {
  /// Built inside each test, not in setUp: streams created outside the test's
  /// zone do not deliver while it runs.
  Future<(LocalLeaderboardConfigService, LocalPerformanceAuditLog)> signIn({
    List<JobOutcome> outcomes = const [],
    List<JobEvaluation> evaluations = const [],
    bool withSeason = false,
  }) async {
    final audit = LocalPerformanceAuditLog();
    final config = LocalLeaderboardConfigService(audit: audit, persist: false);
    if (withSeason) {
      final start = DateTime.now().subtract(const Duration(days: 2));
      final season = await config.createSeason(
        name: 'Season 1',
        startsAt: start,
        endsAt: start.add(const Duration(days: 120)),
        actor: 'Admin',
      );
      await config.startSeason(season.id, actor: 'Admin');
    }
    ConsoleBackend.configure(
      leaderboardConfig: config,
      performanceReview: LocalPerformanceReviewService(
        config: config,
        audit: audit,
        outcomes: outcomes,
        evaluations: evaluations,
      ),
    );
    addTearDown(ConsoleBackend.debugReset);
    final signedIn = await ConsoleSession.instance.signIn('admin', 'x');
    expect(signedIn.isSuccess, isTrue);
    addTearDown(ConsoleSession.instance.signOut);
    return (config, audit);
  }

  Future<void> pump(WidgetTester tester, Size size, Widget page) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_at(size, page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('leaderboard settings: off by default, and a scoring change is saved and audited', (tester) async {
    final (config, audit) = await signIn();
    await pump(tester, _desktop, const AdminLeaderboardPage());

    expect(find.text('Show the leaderboard in the apps'), findsOneWidget);
    expect(find.text('Off — nothing competitive is shown to users'), findsOneWidget);
    expect(find.textContaining('not stored by the On Go API yet'), findsOneWidget);
    expect(find.text('No seasons yet.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Completed job'), '12');
    await tester.enterText(find.widgetWithText(TextField, 'Reason for the change (recorded in the audit log)'),
        'Reward completions more');
    await tester.pump();
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save settings')).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await config.fetchConfig();
    expect(saved.scoring.completedJob, 12);
    expect(saved.enabled, isFalse, reason: 'saving scoring never switches the leaderboard on');
    expect(audit.entries.single.reason, 'Reward completions more');
  });

  testWidgets('leaderboard settings: an invalid value is refused with the reason', (tester) async {
    final (config, _) = await signIn();
    await pump(tester, _desktop, const AdminLeaderboardPage());

    await tester.enterText(find.widgetWithText(TextField, 'Small job share (0–1)'), '2');
    await tester.pump();
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save settings')).onPressed!();
    await tester.pump();

    expect(find.text('The small-job share must be between 0 and 1.'), findsOneWidget);
    expect(await config.fetchConfig(), LeaderboardConfig.defaults);
  });

  testWidgets('performance: says plainly when no records have reached the console', (tester) async {
    await signIn(withSeason: true);
    await pump(tester, _phone, const AdminPerformancePage());

    expect(find.text('No performance records here yet'), findsOneWidget);
    expect(find.text('No scores this season.'), findsOneWidget);
  });

  testWidgets('performance: a standings preview and evaluation statistics from the records given', (tester) async {
    // After the season was started: points only count from then.
    final at = DateTime.now().add(const Duration(minutes: 5));
    await signIn(
      withSeason: true,
      outcomes: [
        JobOutcome(
          id: JobOutcome.idFor(JobOutcomeKind.completed, 'j1', 'Ana', at),
          jobId: 'j1',
          mechanicId: 'Ana',
          kind: JobOutcomeKind.completed,
          at: at,
          clientId: 'Client',
        ),
      ],
      evaluations: [
        JobEvaluation(
          jobId: 'j1',
          clientId: 'Client',
          mechanicId: 'Ana',
          requiredAt: at,
          job: EvaluatedJobSummary(problem: 'Flat tire', location: 'Here', urgency: 'Normal', paidAt: at),
        ).submitted(const EvaluationSubmission(rating: 5), at: at),
      ],
    );
    await pump(tester, _desktop, const AdminPerformancePage());

    expect(find.text('No performance records here yet'), findsNothing);
    expect(find.text('Preview — not shown to users while the leaderboard is off'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('★ 5.00 from 1'), findsOneWidget);
    expect(find.textContaining('client Client'), findsOneWidget, reason: 'admins can see who evaluated');
  });
}
