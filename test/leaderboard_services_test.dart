import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console_backend/local/local_leaderboard_config_service.dart';
import 'package:on_go_console_backend/local/local_performance_audit_log.dart';
import 'package:on_go_console_backend/local/local_performance_review_service.dart';
import 'package:on_go_shared/on_go_shared.dart';

JobOutcome _done(String job, String mechanic, DateTime at, {String client = 'client-a'}) => JobOutcome(
      id: JobOutcome.idFor(JobOutcomeKind.completed, job, mechanic, at),
      jobId: job,
      mechanicId: mechanic,
      kind: JobOutcomeKind.completed,
      at: at,
      clientId: client,
    );

JobEvaluation _rated(String job, String mechanic, int stars, DateTime at) => JobEvaluation(
      jobId: job,
      clientId: 'client-a',
      mechanicId: mechanic,
      requiredAt: at,
      job: EvaluatedJobSummary(problem: 'Flat tire', location: 'Here', urgency: 'Normal', paidAt: at),
    ).submitted(EvaluationSubmission(rating: stars), at: at);

void main() {
  final now = DateTime(2027, 2, 1, 12);

  group('LocalLeaderboardConfigService', () {
    test('starts disabled, with no seasons', () async {
      final service = LocalLeaderboardConfigService(persist: false, clock: () => now);
      expect((await service.fetchConfig()).enabled, isFalse);
      expect(await service.listSeasons(), isEmpty);
    });

    test('refuses invalid settings and records every change with who made it', () async {
      final audit = LocalPerformanceAuditLog();
      final service = LocalLeaderboardConfigService(audit: audit, persist: false, clock: () => now);

      await expectLater(
        service.updateConfig(LeaderboardConfig.defaults.copyWith(maxEffectiveMultiplier: 0.2), actor: 'Admin'),
        throwsA(isA<ApiException>()),
      );
      await service.updateConfig(LeaderboardConfig.defaults.copyWith(enabled: true), actor: 'Admin', reason: 'Launch');

      expect((await service.fetchConfig()).enabled, isTrue);
      expect(audit.entries.single.action, PerformanceAuditAction.configUpdated);
      expect(audit.entries.single.actor, 'Admin');
      expect(audit.entries.single.reason, 'Launch');
    });

    test('seasons: create, start one at a time, end with final placements', () async {
      final service = LocalLeaderboardConfigService(persist: false, clock: () => now);
      final one = await service.createSeason(
        name: 'Season 1',
        startsAt: DateTime(2027, 1, 1),
        endsAt: DateTime(2027, 5, 1),
        actor: 'Admin',
      );
      final two = await service.createSeason(
        name: 'Season 2',
        startsAt: DateTime(2027, 5, 1),
        endsAt: DateTime(2027, 9, 1),
        actor: 'Admin',
      );
      await expectLater(
        service.createSeason(name: 'Bad', startsAt: DateTime(2027, 5, 1), endsAt: DateTime(2027, 4, 1), actor: 'Admin'),
        throwsA(isA<ApiException>()),
      );

      final started = await service.startSeason(one.id, actor: 'Admin');
      expect(started.status, SeasonStatus.active);
      await expectLater(service.startSeason(two.id, actor: 'Admin'), throwsA(isA<ApiException>()),
          reason: 'only one season runs at a time');

      final ended = await service.endSeason(
        one.id,
        actor: 'Admin',
        results: const [SeasonResult(mechanicId: 'Ana', placement: 1, points: 40)],
      );
      expect(ended.status, SeasonStatus.ended);
      expect(ended.results.single.placement, 1);
      expect(ended.accumulatesAt(now.add(const Duration(minutes: 1))), isFalse,
          reason: 'nothing counts after it ended');
    });
  });

  group('LocalPerformanceReviewService', () {
    Future<(LocalLeaderboardConfigService, Season)> seasonRunning(LocalPerformanceAuditLog audit) async {
      final config = LocalLeaderboardConfigService(audit: audit, persist: false, clock: () => DateTime(2027, 1, 1));
      final season = await config.createSeason(
        name: 'Season 1',
        startsAt: DateTime(2027, 1, 1),
        endsAt: DateTime(2027, 5, 1),
        actor: 'Admin',
      );
      return (config, await config.startSeason(season.id, actor: 'Admin'));
    }

    test('with nothing reaching the console, it says so and shows nothing', () async {
      final audit = LocalPerformanceAuditLog();
      final (config, season) = await seasonRunning(audit);
      final review = LocalPerformanceReviewService(config: config, audit: audit);
      expect(review.hasData, isFalse);
      expect(await review.standings(season.id), isEmpty);
      expect(await review.evaluations(), isEmpty);
    });

    test('standings, breakdown, invalidation with a reason, and signed adjustments — all audited', () async {
      final audit = LocalPerformanceAuditLog();
      final (config, season) = await seasonRunning(audit);
      final review = LocalPerformanceReviewService(
        config: config,
        audit: audit,
        outcomes: [_done('j1', 'Ana', now), _done('j2', 'Ben', now.add(const Duration(hours: 1)), client: 'b')],
        evaluations: [_rated('j1', 'Ana', 5, now)],
        clock: () => now,
      );

      expect(review.hasData, isTrue);
      expect((await review.standings(season.id)).map((s) => s.mechanicId), ['Ana', 'Ben']);
      expect((await review.scoreLines(season.id, 'Ana')).map((l) => l.source),
          containsAll([ScoreSource.jobCompleted, ScoreSource.evaluation]));

      await expectLater(review.invalidateEvaluation('evaluation_j1', reason: '', actor: 'Admin'),
          throwsA(isA<ApiException>()));
      final voided = await review.invalidateEvaluation('evaluation_j1', reason: 'Self-dealing', actor: 'Admin');
      expect(voided.status, EvaluationStatus.voided);
      expect(voided.clientId, 'client-a', reason: 'the record is kept');

      await expectLater(
        review.adjustScore(ScoreAdjustment(
          id: 'bad',
          seasonId: season.id,
          mechanicId: 'Ben',
          points: 5,
          reason: '',
          actor: 'Admin',
          createdAt: now,
        )),
        throwsA(isA<ApiException>()),
      );
      await review.adjustScore(ScoreAdjustment(
        id: 'a1',
        seasonId: season.id,
        mechanicId: 'Ben',
        points: 5,
        reason: 'Missed completion',
        actor: 'Admin',
        createdAt: now,
      ));

      final standings = await review.standings(season.id);
      expect(standings.first.mechanicId, 'Ben');
      expect(standings.first.points, 15);
      expect(standings.last.points, 10, reason: "Ana's invalidated 5★ no longer counts");

      final actions = (await review.auditTrail()).map((e) => e.action).toList();
      expect(actions.take(2), [PerformanceAuditAction.scoreAdjusted, PerformanceAuditAction.evaluationInvalidated]);
    });
  });
}
