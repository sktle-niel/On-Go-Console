import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';

/// Mechanic Ranks: what each rank asks for, and the points multiplier it
/// gives.
///
/// A mechanic's rank is worked out on the phone from their completed jobs,
/// number of reviews and average rating, against what is set here, and the
/// multiplier scales the points they earn on every paid job. These settings
/// are not in the API contract yet ([RankPolicyApi]), and the page says so.
class AdminRanksPage extends StatefulWidget {
  const AdminRanksPage({super.key});

  @override
  State<AdminRanksPage> createState() => _AdminRanksPageState();
}

/// The inputs for one rank.
class _RankFields {
  final multiplier = TextEditingController();
  final jobs = TextEditingController();
  final reviews = TextEditingController();
  final rating = TextEditingController();

  void dispose() {
    multiplier.dispose();
    jobs.dispose();
    reviews.dispose();
    rating.dispose();
  }
}

class _AdminRanksPageState extends State<AdminRanksPage> {
  /// Subscribed here rather than through a `StreamBuilder` in [build] — see
  /// `AdminAuditPage` for why a page under [ConsoleShell] must own its
  /// subscription.
  StreamSubscription<RankPolicy>? _watch;

  RankPolicy _saved = RankPolicy.defaults;

  final Map<MechanicRank, _RankFields> _fields = {
    for (final rank in MechanicRank.values) rank: _RankFields(),
  };

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _watch = ConsoleBackend.instance.rankPolicy.watch().listen(
      (policy) {
        if (!mounted) return;
        setState(() {
          _saved = policy;
          _fill(policy);
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _error = error is ApiException ? error.message : 'The ranks could not be loaded.');
      },
    );
  }

  @override
  void dispose() {
    _watch?.cancel();
    for (final fields in _fields.values) {
      fields.dispose();
    }
    super.dispose();
  }

  void _fill(RankPolicy policy) {
    for (final rank in MechanicRank.values) {
      final tier = policy.tierFor(rank);
      final fields = _fields[rank]!;
      fields.multiplier.text = formatPoints(tier.multiplier);
      fields.jobs.text = '${tier.requirement.completedJobs}';
      fields.reviews.text = '${tier.requirement.reviews}';
      fields.rating.text = formatPoints(tier.requirement.averageRating);
    }
  }

  /// The ranks the fields describe, or null when a field will not parse.
  RankPolicy? get _edited {
    var next = _saved;
    for (final rank in MechanicRank.values) {
      final fields = _fields[rank]!;
      final multiplier = double.tryParse(fields.multiplier.text.trim());
      if (multiplier == null) return null;
      final RankRequirement requirement;
      if (rank == MechanicRank.iron) {
        requirement = RankRequirement.none;
      } else {
        final jobs = int.tryParse(fields.jobs.text.trim());
        final reviews = int.tryParse(fields.reviews.text.trim());
        final rating = double.tryParse(fields.rating.text.trim());
        if (jobs == null || reviews == null || rating == null) return null;
        requirement = RankRequirement(completedJobs: jobs, reviews: reviews, averageRating: rating);
      }
      next = next.withTier(rank, RankTier(requirement: requirement, multiplier: multiplier));
    }
    return next;
  }

  /// What is wrong, worded for the admin.
  String _problem() {
    for (final rank in MechanicRank.values) {
      final fields = _fields[rank]!;
      if (double.tryParse(fields.multiplier.text.trim()) == null) {
        return '${rank.label}: the multiplier must be a number, like 1.5.';
      }
      if (rank == MechanicRank.iron) continue;
      if (int.tryParse(fields.jobs.text.trim()) == null) {
        return '${rank.label}: completed jobs must be a whole number.';
      }
      if (int.tryParse(fields.reviews.text.trim()) == null) {
        return '${rank.label}: reviews must be a whole number.';
      }
      if (double.tryParse(fields.rating.text.trim()) == null) {
        return '${rank.label}: the average rating must be a number, like 4.5.';
      }
    }
    return _edited?.problem ?? 'Check the values and try again.';
  }

  bool get _dirty {
    final edited = _edited;
    return edited == null || edited != _saved;
  }

  Future<void> _save() async {
    final edited = _edited;
    if (edited == null || !edited.isValid) {
      setState(() => _error = _problem());
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ConsoleBackend.instance.rankPolicy.update(edited);
      if (mounted) showConsoleMessage(context, 'Mechanic ranks updated');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _error = null;
      _fill(RankPolicy.defaults);
    });
  }

  void _revert() {
    setState(() {
      _error = null;
      _fill(_saved);
    });
  }

  /// The saved settings for [rank] in one line: "x1.5 · 30 jobs · 15 reviews · 4★".
  String _summary(MechanicRank rank) {
    final tier = _saved.tierFor(rank);
    final multiplier = formatMultiplier(tier.multiplier);
    if (rank == MechanicRank.iron) return '$multiplier · Starting rank';
    final requirement = tier.requirement;
    return '$multiplier · ${requirement.completedJobs} jobs · ${requirement.reviews} reviews · '
        '${formatPoints(requirement.averageRating)}★';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
                  _AboutRanks(usesApi: ConsoleBackend.instance.usesApi),
                  SizedBox(height: context.layout.sectionSpacing),
                  for (final rank in MechanicRank.values) ...[
                    ConsoleCard(
                      title: rank.label,
                      subtitle: _summary(rank),
                      child: _RankEditor(
                        rank: rank,
                        fields: _fields[rank]!,
                        enabled: !_busy,
                        onChanged: () => setState(() => _error = null),
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                  ],
                  if (_error != null) ...[
                    Text(_error!, style: text.bodySmall?.copyWith(color: ConsoleColors.danger)),
                    SizedBox(height: context.layout.sectionSpacing),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton(
                        onPressed: _busy || !_dirty ? null : _save,
                        child: Text(_busy ? 'Saving…' : 'Save changes'),
                      ),
                      OutlinedButton(
                        onPressed: _busy || !_dirty ? null : _revert,
                        child: const Text('Discard changes'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _resetToDefaults,
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

/// One rank's multiplier and requirements.
class _RankEditor extends StatelessWidget {
  const _RankEditor({
    required this.rank,
    required this.fields,
    required this.enabled,
    required this.onChanged,
  });

  final MechanicRank rank;
  final _RankFields fields;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberField(
          label: 'Points multiplier',
          helper: 'Scales the points a mechanic at this rank earns on each paid job. '
              '${formatMultiplier(minRankMultiplier)} to ${formatMultiplier(maxRankMultiplier)}.',
          prefix: 'x',
          controller: fields.multiplier,
          decimal: true,
          enabled: enabled,
          onChanged: onChanged,
        ),
        if (rank == MechanicRank.iron)
          Text(
            'Every mechanic starts at Iron, so it has no requirements.',
            style: text.bodySmall?.copyWith(color: ConsoleColors.textMuted),
          )
        else ...[
          _NumberField(
            label: 'Completed jobs',
            helper: 'At least this many paid jobs',
            controller: fields.jobs,
            enabled: enabled,
            onChanged: onChanged,
          ),
          _NumberField(
            label: 'Reviews',
            helper: 'At least this many client reviews',
            controller: fields.reviews,
            enabled: enabled,
            onChanged: onChanged,
          ),
          _NumberField(
            label: 'Average rating',
            helper: 'At least this average, out of ${formatPoints(maxRating)}',
            suffix: '★',
            controller: fields.rating,
            decimal: true,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

/// One editable number.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.decimal = false,
  });

  final String label;
  final String helper;
  final String? prefix;
  final String? suffix;
  final bool decimal;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          prefixText: prefix,
          suffixText: suffix,
        ),
      ),
    );
  }
}

/// How ranks work, and where these settings are kept.
class _AboutRanks extends StatelessWidget {
  const _AboutRanks({required this.usesApi});

  final bool usesApi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget line(IconData icon, Color color, String message) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: text.bodySmall)),
            ],
          ),
        );

    return ConsoleCard(
      title: 'How ranks work',
      child: Column(
        children: [
          line(
            Icons.trending_up,
            ConsoleColors.textMuted,
            "A mechanic's rank comes from their completed jobs, number of reviews and "
            'average rating. They reach a rank once they meet all three of its requirements, '
            'and each rank must require at least as much as the one below it.',
          ),
          line(
            Icons.stars_outlined,
            ConsoleColors.textMuted,
            'The rank multiplies the points a mechanic earns on every paid job, from '
            '${formatMultiplier(minRankMultiplier)} up to ${formatMultiplier(maxRankMultiplier)}.',
          ),
          if (!usesApi)
            line(
              Icons.computer_outlined,
              ConsoleColors.textMuted,
              'This is a local console build, so nothing on this page reaches a phone.',
            ),
          line(
            Icons.cloud_off_outlined,
            ConsoleColors.warning,
            'Ranks are not stored by the On Go API yet. These settings are kept in this '
            'browser, and phones rank mechanics by the defaults until the backend adds them.',
          ),
        ],
      ),
    );
  }
}
