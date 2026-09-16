import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';
import 'admin_leaderboard_page.dart' show formatConsoleDate;

/// Performance: what an admin reviews behind the leaderboard.
///
/// The season's standings — a preview while the leaderboard is off — with
/// where every point came from; evaluations, including their clients, with a
/// reasoned invalidation; reward point transactions; activity flagged for a
/// look; and the audit log of every change. There is no "set the score"
/// control: a score moves only by a signed adjustment with a reason.
class AdminPerformancePage extends StatefulWidget {
  const AdminPerformancePage({super.key});

  @override
  State<AdminPerformancePage> createState() => _AdminPerformancePageState();
}

class _AdminPerformancePageState extends State<AdminPerformancePage> {
  StreamSubscription<List<Season>>? _seasonsWatch;
  StreamSubscription<LeaderboardConfig>? _configWatch;

  List<Season> _seasons = const [];
  LeaderboardConfig _config = LeaderboardConfig.defaults;
  String? _seasonId;

  List<LeaderboardStanding> _standings = const [];
  List<SuspiciousActivity> _flags = const [];
  List<JobEvaluation> _evaluations = const [];
  List<PointTransaction> _transactions = const [];
  List<PerformanceAuditEntry> _audit = const [];
  String? _error;

  PerformanceReviewApi get _review => ConsoleBackend.instance.performanceReview;

  String get _actor => ConsoleSession.instance.actorName;

  @override
  void initState() {
    super.initState();
    final api = ConsoleBackend.instance.leaderboardConfig;
    _configWatch = api.watchConfig().listen((config) {
      if (mounted) setState(() => _config = config);
    }, onError: (Object _) {});
    _seasonsWatch = api.watchSeasons().listen((seasons) {
      if (!mounted) return;
      final keep = seasons.any((s) => s.id == _seasonId);
      setState(() {
        _seasons = seasons;
        if (!keep) _seasonId = _defaultSeason(seasons)?.id;
      });
      unawaited(_reload());
    }, onError: (Object _) {});
    unawaited(_reload());
  }

  static Season? _defaultSeason(List<Season> seasons) {
    for (final season in seasons) {
      if (season.status == SeasonStatus.active) return season;
    }
    return seasons.isEmpty ? null : seasons.last;
  }

  @override
  void dispose() {
    _seasonsWatch?.cancel();
    _configWatch?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final evaluations = await _review.evaluations();
      final transactions = await _review.pointTransactions();
      final audit = await _review.auditTrail();
      final seasonId = _seasonId;
      final standings = seasonId == null ? const <LeaderboardStanding>[] : await _review.standings(seasonId);
      final flags = seasonId == null ? const <SuspiciousActivity>[] : await _review.suspiciousActivity(seasonId);
      if (!mounted) return;
      setState(() {
        _evaluations = evaluations;
        _transactions = transactions;
        _audit = audit;
        _standings = standings;
        _flags = flags;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _showBreakdown(LeaderboardStanding standing) async {
    final seasonId = _seasonId;
    if (seasonId == null) return;
    final adjust = await showDialog<bool>(
      context: context,
      builder: (_) => _BreakdownDialog(
        standing: standing,
        lines: _review.scoreLines(seasonId, standing.mechanicId),
      ),
    );
    if (adjust == true && mounted) await _adjust(standing.mechanicId);
  }

  Future<void> _adjust(String mechanicId) async {
    final seasonId = _seasonId;
    if (seasonId == null) return;
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _AdjustDialog(mechanicId: mechanicId),
    );
    if (result == null || !mounted) return;
    try {
      await _review.adjustScore(ScoreAdjustment(
        id: 'adjustment_${DateTime.now().microsecondsSinceEpoch}',
        seasonId: seasonId,
        mechanicId: mechanicId,
        points: result.$1,
        reason: result.$2,
        actor: _actor,
        createdAt: DateTime.now(),
      ));
      if (mounted) showConsoleMessage(context, 'Adjustment recorded');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  Future<void> _invalidate(JobEvaluation evaluation) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(
        title: 'Invalidate this evaluation?',
        message: 'It stops counting toward the rating, rank and season score. It is kept, with your reason.',
        action: 'Invalidate',
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await _review.invalidateEvaluation(evaluation.id, reason: reason, actor: _actor);
      if (mounted) showConsoleMessage(context, 'Evaluation invalidated');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: ConsoleColors.textMuted);
    final local = ConsoleBackend.instance.localPerformanceReview;
    final noRecords = local != null && !local.hasData;

    return ConsoleShell(
      child: Builder(
        builder: (context) => ListView(
          padding: consolePagePadding(context),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.layout.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (noRecords) ...[
                    ConsoleCard(
                      title: 'No performance records here yet',
                      child: Text(
                        'Evaluations, job outcomes and point transactions are recorded on phones. They reach the '
                        'console once the jobs domain is served by the On Go API; the calculations on this page '
                        'are ready for them.',
                        style: text.bodySmall,
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                  ],
                  if (_error != null) ...[
                    Text(_error!, style: text.bodySmall?.copyWith(color: ConsoleColors.danger)),
                    SizedBox(height: context.layout.sectionSpacing),
                  ],
                  ConsoleCard(
                    title: 'Standings',
                    subtitle: _config.enabled ? 'Public' : 'Preview — not shown to users while the leaderboard is off',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_seasons.isEmpty)
                          Text('No seasons yet — create one under Leaderboard.', style: muted)
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey(_seasonId),
                            initialValue: _seasonId,
                            decoration: const InputDecoration(labelText: 'Season'),
                            items: [
                              for (final season in _seasons)
                                DropdownMenuItem(value: season.id, child: Text('${season.name} · ${season.status.label}')),
                            ],
                            onChanged: (id) {
                              setState(() => _seasonId = id);
                              unawaited(_reload());
                            },
                          ),
                        const SizedBox(height: 12),
                        if (_seasons.isNotEmpty && _standings.isEmpty) Text('No scores this season.', style: muted),
                        for (final standing in _standings)
                          InkWell(
                            onTap: () => _showBreakdown(standing),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 48, child: Text('#${standing.placement}', style: text.titleSmall)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(standing.mechanicId, style: text.titleSmall),
                                        Text(
                                          '${formatPoints(standing.points)} pts · '
                                          '${standing.rating.isEmpty ? 'no ratings' : '★ ${standing.rating.average.toStringAsFixed(1)} (${standing.rating.count})'} · '
                                          '${standing.completedJobs} jobs · '
                                          '${(standing.cancellationRate * 100).round()}% dropped',
                                          style: muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (standing.points > 0 && standing.placement <= _config.gemMaxPlacement)
                                    Text('💎 #${standing.placement} Gem', style: text.bodySmall),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  _EvaluationsCard(evaluations: _evaluations, onInvalidate: _invalidate),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'Point transactions',
                    subtitle: 'Every award of reward points, and why it was that size',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_transactions.isEmpty) Text('None yet.', style: muted),
                        for (final t in _transactions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t.mechanicId} · ${t.sourceType.label} ${t.sourceId}', style: text.titleSmall),
                                Text(
                                  '${formatPoints(t.basePoints)} × ${t.rank.label} ${formatMultiplier(t.rankMultiplier)}'
                                  '${t.bonusMultiplier > 0 ? ' + ${formatPoints(t.bonusMultiplier)}' : ''}'
                                  ' × seasonal ${formatMultiplier(t.leaderboardMultiplier)}'
                                  ' = ${formatPoints(t.finalPoints)} pts'
                                  '${t.wasCapped ? ' (capped at ${formatMultiplier(t.cap!)})' : ''}',
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'Flagged for review',
                    subtitle: 'Patterns worth a look — never acted on automatically',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_flags.isEmpty) Text('Nothing flagged.', style: muted),
                        for (final flag in _flags)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${flag.kind.label} · ${flag.mechanicId}', style: text.titleSmall),
                                Text('${flag.detail} Jobs: ${flag.jobIds.join(', ')}', style: muted),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'Audit log',
                    subtitle: 'Settings, seasons, adjustments and invalidations',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_audit.isEmpty) Text('No changes recorded.', style: muted),
                        for (final entry in _audit)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.action.label} · ${entry.actor}', style: text.titleSmall),
                                Text(
                                  [
                                    formatConsoleDate(entry.at),
                                    if (entry.detail != null) entry.detail!,
                                    if (entry.reason != null) 'Reason: ${entry.reason}',
                                  ].join(' · '),
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationsCard extends StatelessWidget {
  const _EvaluationsCard({required this.evaluations, required this.onInvalidate});

  final List<JobEvaluation> evaluations;
  final ValueChanged<JobEvaluation> onInvalidate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: ConsoleColors.textMuted);
    final counted = evaluations.where((e) => e.counts).toList();
    final summary = RatingSummary.of([for (final e in counted) e.rating!]);
    final pending = evaluations.where((e) => e.evaluationRequired).length;
    final tagCounts = <EvaluationTag, int>{};
    for (final evaluation in counted) {
      for (final tag in evaluation.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ConsoleCard(
      title: 'Evaluations',
      subtitle: 'Anonymous to mechanics; the client is shown here for investigation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.isEmpty
                ? 'No counted evaluations · $pending awaiting clients'
                : '★ ${summary.average.toStringAsFixed(2)} from ${summary.count} · '
                    '${((summary.shareAtLeast(4) ?? 0) * 100).round()}% at 4★ or more · $pending awaiting clients',
            style: text.bodyMedium,
          ),
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(topTags.take(5).map((e) => '${e.key.label} ${e.value}').join(' · '), style: muted),
          ],
          const SizedBox(height: 12),
          for (final evaluation in evaluations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${evaluation.rating == null ? '—' : '${evaluation.rating}★'} · ${evaluation.mechanicId} · '
                          'client ${evaluation.clientId}',
                          style: text.titleSmall,
                        ),
                        Text(
                          [
                            'Job ${evaluation.jobId}',
                            evaluation.status.wireName,
                            if (evaluation.feedback.isNotEmpty) '“${evaluation.feedback}”',
                            if (evaluation.voidReason != null) 'Invalidated: ${evaluation.voidReason}',
                          ].join(' · '),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  if (evaluation.counts)
                    TextButton(onPressed: () => onInvalidate(evaluation), child: const Text('Invalidate')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownDialog extends StatelessWidget {
  const _BreakdownDialog({required this.standing, required this.lines});

  final LeaderboardStanding standing;
  final Future<List<ScoreLine>> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: ConsoleColors.textMuted);
    return AlertDialog(
      title: Text('#${standing.placement} ${standing.mechanicId}'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<ScoreLine>>(
          future: lines,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <ScoreLine>[];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatPoints(standing.points)} season points', style: text.titleMedium),
                  const SizedBox(height: 8),
                  for (final category in ScoreCategory.values)
                    if (standing.byCategory[category] != null)
                      Text('${category.label}: ${formatPoints(standing.byCategory[category]!)}', style: text.bodySmall),
                  const Divider(height: 20),
                  for (final line in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${line.points > 0 ? '+' : ''}${formatPoints(line.points)} · ${line.source.wireName} · '
                        '${line.sourceId}${line.note == null ? '' : ' · ${line.note}'} · ${formatConsoleDate(line.at)}',
                        style: muted,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
        OutlinedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Adjust score')),
      ],
    );
  }
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.mechanicId});

  final String mechanicId;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _points = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _points.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final points = double.tryParse(_points.text.trim());
    if (points == null || points == 0) {
      setState(() => _error = 'Enter the points to add, or a negative number to take away.');
      return;
    }
    if (_reason.text.trim().length < 5) {
      setState(() => _error = 'Say why — every adjustment needs a reason.');
      return;
    }
    Navigator.pop(context, (points, _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust ${widget.mechanicId}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _points,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Points (+ or −)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Reason (recorded in the audit log)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: ConsoleColors.danger, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Record adjustment')),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.action});

  final String title;
  final String message;
  final String action;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _reason.text.trim().length >= 5;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Reason (required)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: valid ? () => Navigator.pop(context, _reason.text.trim()) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
