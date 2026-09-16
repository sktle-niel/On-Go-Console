import 'package:on_go_shared/on_go_shared.dart';

import 'local_performance_audit_log.dart';

/// Standings, score breakdowns, evaluations and point transactions for the
/// admin to review, held in this browser.
///
/// Locally there is nothing to review: evaluations, job outcomes and point
/// transactions are recorded on phones, and nothing carries them to the
/// console until the jobs domain is served by the On Go API. The calculations
/// are real — the same [LeaderboardEngine] a phone and a server use — and run
/// on whatever records this service is given, so the pages are ready for the
/// data the moment it arrives. [hasData] is what they check to say so.
class LocalPerformanceReviewService implements PerformanceReviewApi {
  LocalPerformanceReviewService({
    required LeaderboardConfigApi config,
    LocalPerformanceAuditLog? audit,
    Iterable<JobOutcome> outcomes = const [],
    Iterable<JobEvaluation> evaluations = const [],
    Iterable<PointTransaction> transactions = const [],
    DateTime Function()? clock,
  })  : _config = config,
        audit = audit ?? LocalPerformanceAuditLog(),
        _outcomes = [...outcomes],
        _evaluations = [...evaluations],
        _transactions = [...transactions],
        _clock = clock ?? DateTime.now;

  final LeaderboardConfigApi _config;
  final LocalPerformanceAuditLog audit;
  final List<JobOutcome> _outcomes;
  final List<JobEvaluation> _evaluations;
  final List<PointTransaction> _transactions;
  final List<ScoreAdjustment> _adjustments = [];
  final DateTime Function() _clock;

  /// Whether any performance record has reached this console.
  bool get hasData => _outcomes.isNotEmpty || _evaluations.isNotEmpty || _transactions.isNotEmpty;

  Future<(Season, LeaderboardEngine)> _season(String seasonId) async {
    final seasons = await _config.listSeasons();
    for (final season in seasons) {
      if (season.id == seasonId) return (season, LeaderboardEngine(await _config.fetchConfig()));
    }
    throw const ApiException(ApiErrorKind.notFound, 'That season no longer exists.');
  }

  @override
  Future<List<LeaderboardStanding>> standings(String seasonId) async {
    final (season, engine) = await _season(seasonId);
    return engine.standings(
      season: season,
      outcomes: _outcomes,
      evaluations: _evaluations,
      adjustments: _adjustments,
    );
  }

  @override
  Future<List<ScoreLine>> scoreLines(String seasonId, String mechanicId) async {
    final (season, engine) = await _season(seasonId);
    return engine
        .scoreLines(season: season, outcomes: _outcomes, evaluations: _evaluations, adjustments: _adjustments)
        .where((line) => line.mechanicId == mechanicId)
        .toList();
  }

  @override
  Future<List<PointTransaction>> pointTransactions({String? mechanicId}) async =>
      _transactions.where((t) => mechanicId == null || t.mechanicId == mechanicId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<JobEvaluation>> evaluations({String? mechanicId}) async =>
      _evaluations.where((e) => mechanicId == null || e.mechanicId == mechanicId).toList()
        ..sort((a, b) => (b.submittedAt ?? b.requiredAt).compareTo(a.submittedAt ?? a.requiredAt));

  @override
  Future<List<SuspiciousActivity>> suspiciousActivity(String seasonId) async {
    final (season, engine) = await _season(seasonId);
    return engine.suspiciousActivity(season: season, outcomes: _outcomes);
  }

  @override
  Future<JobEvaluation> invalidateEvaluation(String evaluationId, {required String reason, required String actor}) async {
    if (reason.trim().length < 5) {
      throw const ApiException(ApiErrorKind.rejected, 'Say why — invalidating an evaluation needs a reason.');
    }
    final index = _evaluations.indexWhere((e) => e.id == evaluationId);
    if (index < 0) throw const ApiException(ApiErrorKind.notFound, 'That evaluation no longer exists.');
    if (_evaluations[index].status == EvaluationStatus.voided) {
      throw const ApiException(ApiErrorKind.rejected, 'That evaluation is already invalidated.');
    }
    final voided = _evaluations[index].voided(reason.trim(), at: _clock());
    _evaluations[index] = voided;
    audit.record(
      action: PerformanceAuditAction.evaluationInvalidated,
      actor: actor,
      subjectId: evaluationId,
      reason: reason.trim(),
      detail: '${voided.rating ?? '—'}★ for ${voided.mechanicId}',
    );
    return voided;
  }

  @override
  Future<ScoreAdjustment> adjustScore(ScoreAdjustment adjustment) async {
    final problem = adjustment.problem;
    if (problem != null) throw ApiException(ApiErrorKind.rejected, problem);
    await _season(adjustment.seasonId);
    _adjustments.add(adjustment);
    audit.record(
      action: PerformanceAuditAction.scoreAdjusted,
      actor: adjustment.actor,
      subjectId: adjustment.mechanicId,
      reason: adjustment.reason,
      detail: '${adjustment.points > 0 ? '+' : ''}${formatPoints(adjustment.points)} points',
    );
    return adjustment;
  }

  @override
  Future<List<PerformanceAuditEntry>> auditTrail() async => audit.entries;
}
