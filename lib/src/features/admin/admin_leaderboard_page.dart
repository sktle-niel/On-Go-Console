import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';

/// Leaderboard: whether it is public, its seasons, and every value that
/// scores it.
///
/// Seasonal and separate from rank: rank is long-term progression and never
/// resets; a season's score does. Every change here is recorded in the audit
/// log with who made it. None of it is in the On Go API contract yet
/// ([LeaderboardConfigApi]) — the page says so.
class AdminLeaderboardPage extends StatefulWidget {
  const AdminLeaderboardPage({super.key});

  @override
  State<AdminLeaderboardPage> createState() => _AdminLeaderboardPageState();
}

class _AdminLeaderboardPageState extends State<AdminLeaderboardPage> {
  StreamSubscription<LeaderboardConfig>? _configWatch;
  StreamSubscription<List<Season>>? _seasonsWatch;

  LeaderboardConfig _saved = LeaderboardConfig.defaults;
  List<Season> _seasons = const [];

  final Map<String, TextEditingController> _fields = {};
  final List<(TextEditingController, TextEditingController)> _tiers = [];
  final _reason = TextEditingController();

  bool _busy = false;
  String? _error;

  LeaderboardConfigApi get _api => ConsoleBackend.instance.leaderboardConfig;

  String get _actor => ConsoleSession.instance.actorName;

  TextEditingController _field(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _fill(LeaderboardConfig.defaults);
    _configWatch = _api.watchConfig().listen(
      (config) {
        if (!mounted) return;
        setState(() {
          // Unsaved edits survive a change arriving from elsewhere.
          final keepEdits = _dirty;
          _saved = config;
          if (!keepEdits) _fill(config);
        });
      },
      onError: (Object error) => _failed(error, 'The leaderboard settings could not be loaded.'),
    );
    _seasonsWatch = _api.watchSeasons().listen(
      (seasons) {
        if (mounted) setState(() => _seasons = seasons);
      },
      onError: (Object error) => _failed(error, 'The seasons could not be loaded.'),
    );
  }

  void _failed(Object error, String fallback) {
    if (mounted) setState(() => _error = error is ApiException ? error.message : fallback);
  }

  @override
  void dispose() {
    _configWatch?.cancel();
    _seasonsWatch?.cancel();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final (upTo, multiplier) in _tiers) {
      upTo.dispose();
      multiplier.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  void _fill(LeaderboardConfig config) {
    final s = config.scoring;
    _field('completedJob').text = formatPoints(s.completedJob);
    for (var star = 1; star <= 5; star++) {
      _field('star$star').text = formatPoints(s.ratingPoints[star - 1]);
    }
    _field('onTime').text = formatPoints(s.onTimeArrival);
    _field('valuePerThousand').text = formatPoints(s.jobValuePerThousandPesos);
    _field('maxValue').text = formatPoints(s.maxJobValuePoints);
    _field('smallPayout').text = formatPoints(s.smallJobPayout);
    _field('smallFactor').text = formatPoints(s.smallJobFactor);
    _field('perClientDay').text = '${s.maxScoredJobsPerClientPerDay}';
    _field('cancellation').text = formatPoints(s.cancellationPenalty);
    _field('expiry').text = formatPoints(s.expiryPenalty);
    _field('gemMax').text = '${config.gemMaxPlacement}';
    _field('cap').text = formatPoints(config.maxEffectiveMultiplier);
    _field('suspicious').text = '${config.suspiciousJobsPerHour}';
    _field('minMechanics').text = config.minActiveMechanics?.toString() ?? '';
    _field('minJobs').text = config.minCompletedJobs?.toString() ?? '';

    for (final (upTo, multiplier) in _tiers) {
      upTo.dispose();
      multiplier.dispose();
    }
    _tiers
      ..clear()
      ..addAll([
        for (final tier in config.placementMultipliers)
          (
            TextEditingController(text: '${tier.upToPlacement}'),
            TextEditingController(text: formatPoints(tier.multiplier)),
          ),
      ]);
  }

  /// The settings the fields describe, or null when a field will not parse.
  LeaderboardConfig? get _edited {
    double? d(String key) => double.tryParse(_field(key).text.trim());
    int? i(String key) => int.tryParse(_field(key).text.trim());

    final stars = [for (var star = 1; star <= 5; star++) d('star$star')];
    final values = [
      d('completedJob'), d('onTime'), d('valuePerThousand'), d('maxValue'), d('smallPayout'),
      d('smallFactor'), d('cancellation'), d('expiry'), d('cap'),
    ];
    final ints = [i('perClientDay'), i('gemMax'), i('suspicious')];
    if (stars.contains(null) || values.contains(null) || ints.contains(null)) return null;

    int? optional(String key) {
      final text = _field(key).text.trim();
      return text.isEmpty ? null : int.tryParse(text);
    }

    if ((_field('minMechanics').text.trim().isNotEmpty && optional('minMechanics') == null) ||
        (_field('minJobs').text.trim().isNotEmpty && optional('minJobs') == null)) {
      return null;
    }

    final tiers = <PlacementMultiplier>[];
    for (final (upTo, multiplier) in _tiers) {
      final placement = int.tryParse(upTo.text.trim());
      final value = double.tryParse(multiplier.text.trim());
      if (placement == null || value == null) return null;
      tiers.add(PlacementMultiplier(upToPlacement: placement, multiplier: value));
    }

    return LeaderboardConfig(
      enabled: _saved.enabled,
      scoring: LeaderboardScoring(
        completedJob: values[0]!,
        ratingPoints: [for (final star in stars) star!],
        onTimeArrival: values[1]!,
        jobValuePerThousandPesos: values[2]!,
        maxJobValuePoints: values[3]!,
        smallJobPayout: values[4]!,
        smallJobFactor: values[5]!,
        maxScoredJobsPerClientPerDay: ints[0]!,
        cancellationPenalty: values[6]!,
        expiryPenalty: values[7]!,
      ),
      maxEffectiveMultiplier: values[8]!,
      gemMaxPlacement: ints[1]!,
      suspiciousJobsPerHour: ints[2]!,
      placementMultipliers: tiers,
      minActiveMechanics: optional('minMechanics'),
      minCompletedJobs: optional('minJobs'),
    );
  }

  bool get _dirty {
    final edited = _edited;
    return edited == null || edited != _saved;
  }

  Future<void> _save() async {
    final edited = _edited;
    final problem = edited == null ? 'Every value must be a number.' : edited.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reason = _reason.text.trim();
      await _api.updateConfig(edited!, actor: _actor, reason: reason.isEmpty ? null : reason);
      _reason.clear();
      if (mounted) showConsoleMessage(context, 'Leaderboard settings saved');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final confirmed = await confirmConsoleAction(
      context,
      title: enabled ? 'Make the leaderboard public?' : 'Turn the leaderboard off?',
      message: enabled
          ? 'Clients and mechanics will see standings and Gem badges, and seasonal multipliers will '
              'apply to points.'
          : 'Standings, Gem badges and seasonal multipliers will be hidden again. Evaluations and job '
              'outcomes keep being recorded.',
      confirmLabel: enabled ? 'Make public' : 'Turn off',
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.updateConfig(
        _saved.copyWith(enabled: enabled),
        actor: _actor,
        reason: enabled ? 'Leaderboard made public' : 'Leaderboard turned off',
      );
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  Future<void> _createSeason() async {
    final draft = await showDialog<_SeasonDraft>(context: context, builder: (_) => const _CreateSeasonDialog());
    if (draft == null || !mounted) return;
    try {
      await _api.createSeason(name: draft.name, startsAt: draft.startsAt, endsAt: draft.endsAt, actor: _actor);
      if (mounted) showConsoleMessage(context, 'Season created');
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  Future<void> _startSeason(Season season) async {
    final confirmed = await confirmConsoleAction(
      context,
      title: 'Start ${season.name}?',
      message: 'Season points start counting from now (or its start date, if that is later).',
      confirmLabel: 'Start season',
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.startSeason(season.id, actor: _actor);
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  Future<void> _endSeason(Season season) async {
    final confirmed = await confirmConsoleAction(
      context,
      title: 'End ${season.name}?',
      message: 'Season points stop counting and final placements are recorded. Ranks and lifetime '
          'statistics are not affected.',
      confirmLabel: 'End season',
    );
    if (!confirmed || !mounted) return;
    try {
      List<LeaderboardStanding> standings;
      try {
        standings = await ConsoleBackend.instance.performanceReview.standings(season.id);
      } on ApiException {
        standings = const [];
      }
      await _api.endSeason(
        season.id,
        actor: _actor,
        results: [
          for (final s in standings) SeasonResult(mechanicId: s.mechanicId, placement: s.placement, points: s.points),
        ],
      );
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    }
  }

  void _addTier() => setState(() {
        final last = _tiers.isEmpty ? 0 : (int.tryParse(_tiers.last.$1.text) ?? 0);
        _tiers.add((TextEditingController(text: '${last + 50}'), TextEditingController(text: '1')));
        _error = null;
      });

  void _removeTier(int index) => setState(() {
        final (upTo, multiplier) = _tiers.removeAt(index);
        upTo.dispose();
        multiplier.dispose();
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void changed() => setState(() => _error = null);

    return ConsoleShell(
      child: Builder(
        builder: (context) => ListView(
          padding: consolePagePadding(context),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.layout.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConsoleCard(
                    title: 'Public leaderboard',
                    subtitle: _saved.enabled ? 'Public' : 'Off — nothing competitive is shown to users',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsoleToggleRow(
                          title: 'Show the leaderboard in the apps',
                          subtitle: 'Off: no leaderboard, no Gem badges and no seasonal multiplier. Evaluations '
                              'and job outcomes keep being recorded, and standings can be previewed under Performance.',
                          value: _saved.enabled,
                          onChanged: _setEnabled,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These settings are not stored by the On Go API yet. They are kept in this browser and '
                          'reach no phone until the backend adds them.',
                          style: text.bodySmall?.copyWith(color: ConsoleColors.warning),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  _SeasonsCard(
                    seasons: _seasons,
                    onCreate: _createSeason,
                    onStart: _startSeason,
                    onEnd: _endSeason,
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'Scoring',
                    subtitle: 'Season points — reward good service, not volume',
                    child: _FieldGrid(children: [
                      _NumberField(label: 'Completed job', controller: _field('completedJob'), onChanged: changed),
                      _NumberField(label: 'On-time arrival', controller: _field('onTime'), onChanged: changed),
                      for (var star = 1; star <= 5; star++)
                        _NumberField(label: '$star★ evaluation', controller: _field('star$star'), signed: true, onChanged: changed),
                      _NumberField(label: 'Per ₱1,000 paid', controller: _field('valuePerThousand'), onChanged: changed),
                      _NumberField(label: 'Most for job value', controller: _field('maxValue'), onChanged: changed),
                      _NumberField(label: 'Small job below (₱)', controller: _field('smallPayout'), onChanged: changed),
                      _NumberField(label: 'Small job share (0–1)', controller: _field('smallFactor'), onChanged: changed),
                      _NumberField(
                          label: 'Scored jobs per client per day', controller: _field('perClientDay'), decimal: false, onChanged: changed),
                      _NumberField(label: 'Cancellation penalty', controller: _field('cancellation'), signed: true, onChanged: changed),
                      _NumberField(label: 'Expiry penalty', controller: _field('expiry'), signed: true, onChanged: changed),
                    ]),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'Seasonal multipliers and Gems',
                    subtitle: 'Reward points: base × rank × seasonal, never above the cap',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldGrid(children: [
                          _NumberField(
                              label: 'Gem badge for placements down to #', controller: _field('gemMax'), decimal: false, onChanged: changed),
                          _NumberField(label: 'Most any multiplier may reach (x)', controller: _field('cap'), onChanged: changed),
                          _NumberField(
                              label: 'Flag at jobs per hour', controller: _field('suspicious'), decimal: false, onChanged: changed),
                        ]),
                        const SizedBox(height: 8),
                        Text('Placement tiers', style: text.titleSmall),
                        const SizedBox(height: 8),
                        for (var index = 0; index < _tiers.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                      label: 'Down to #', controller: _tiers[index].$1, decimal: false, onChanged: changed),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _NumberField(label: 'Multiplier (x)', controller: _tiers[index].$2, onChanged: changed),
                                ),
                                IconButton(
                                  tooltip: 'Remove tier',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeTier(index),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addTier,
                            icon: const Icon(Icons.add),
                            label: const Text('Add tier'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    title: 'When to activate',
                    subtitle: 'Guidance for admins — never applied automatically',
                    child: _FieldGrid(children: [
                      _NumberField(
                          label: 'Active mechanics (optional)', controller: _field('minMechanics'), decimal: false, onChanged: changed),
                      _NumberField(
                          label: 'Completed jobs (optional)', controller: _field('minJobs'), decimal: false, onChanged: changed),
                    ]),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  TextField(
                    controller: _reason,
                    decoration: const InputDecoration(labelText: 'Reason for the change (recorded in the audit log)'),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: context.layout.sectionSpacing),
                    Text(_error!, style: text.bodySmall?.copyWith(color: ConsoleColors.danger)),
                  ],
                  SizedBox(height: context.layout.sectionSpacing),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton(
                        onPressed: _busy || !_dirty ? null : _save,
                        child: Text(_busy ? 'Saving…' : 'Save settings'),
                      ),
                      OutlinedButton(
                        onPressed: _busy || !_dirty
                            ? null
                            : () => setState(() {
                                  _error = null;
                                  _fill(_saved);
                                }),
                        child: const Text('Discard changes'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _error = null;
                                  _fill(LeaderboardConfig.defaults.copyWith(enabled: _saved.enabled));
                                }),
                        child: const Text('Reset to defaults'),
                      ),
                    ],
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

class _SeasonsCard extends StatelessWidget {
  const _SeasonsCard({required this.seasons, required this.onCreate, required this.onStart, required this.onEnd});

  final List<Season> seasons;
  final VoidCallback onCreate;
  final ValueChanged<Season> onStart;
  final ValueChanged<Season> onEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      title: 'Seasons',
      subtitle: 'Scores reset each season; ranks and history do not',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (seasons.isEmpty)
            Text('No seasons yet.', style: text.bodySmall?.copyWith(color: ConsoleColors.textMuted)),
          for (final season in seasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${season.name} · ${season.status.label}', style: text.titleSmall),
                        Text(
                          '${formatConsoleDate(season.startsAt)} – ${formatConsoleDate(season.endsAt)}'
                          '${season.results.isEmpty ? '' : ' · ${season.results.length} final placements'}',
                          style: text.bodySmall?.copyWith(color: ConsoleColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (season.status == SeasonStatus.scheduled)
                    TextButton(onPressed: () => onStart(season), child: const Text('Start')),
                  if (season.status == SeasonStatus.active)
                    TextButton(onPressed: () => onEnd(season), child: const Text('End')),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create season'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Jan 5, 2027".
String formatConsoleDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _SeasonDraft {
  const _SeasonDraft(this.name, this.startsAt, this.endsAt);

  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
}

class _CreateSeasonDialog extends StatefulWidget {
  const _CreateSeasonDialog();

  @override
  State<_CreateSeasonDialog> createState() => _CreateSeasonDialogState();
}

class _CreateSeasonDialogState extends State<_CreateSeasonDialog> {
  final _name = TextEditingController();
  late DateTime _startsAt;
  late DateTime _endsAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day);
    // A suggestion — seasons of about four months — never a rule.
    _endsAt = _startsAt.add(const Duration(days: 120));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startsAt : _endsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => start ? _startsAt = picked : _endsAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty && _endsAt.isAfter(_startsAt);
    return AlertDialog(
      title: const Text('Create season'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Season 1'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _pick(start: true), child: Text('Starts ${formatConsoleDate(_startsAt)}')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _pick(start: false), child: Text('Ends ${formatConsoleDate(_endsAt)}')),
          if (!_endsAt.isAfter(_startsAt))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('A season must end after it starts.', style: TextStyle(color: ConsoleColors.danger, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: valid ? () => Navigator.pop(context, _SeasonDraft(_name.text.trim(), _startsAt, _endsAt)) : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Two columns where there is room, one where there is not.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = constraints.maxWidth >= 520 ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.decimal = true,
    this.signed = false,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool decimal;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: signed),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
