import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';

/// Urgency Levels: for Normal, Urgent and Emergency, what a job awards in
/// points, what it adds to the client's bill, and how long the mechanic has to
/// finish it.
///
/// These are the numbers the platform runs on. Nothing in the mobile app
/// carries its own copy: the points a paid job awards (the client and the
/// mechanic earn the same), the additional charge a new job is priced with,
/// its completion deadline and the longest ETA a mechanic may quote all read
/// what is set here. Clients and mechanics are never shown the points.
///
/// Two stores sit behind the one page. Points are the On Go API's points
/// policy. Additional charges and completion times are not in the API
/// contract yet ([UrgencyPolicyApi]), and the page says where each is kept.
class AdminPointsPage extends StatefulWidget {
  const AdminPointsPage({super.key});

  @override
  State<AdminPointsPage> createState() => _AdminPointsPageState();
}

/// The inputs for one urgency level.
class _LevelFields {
  final points = TextEditingController();
  final charge = TextEditingController();
  final time = TextEditingController();
  CompletionTimeUnit unit = CompletionTimeUnit.none;

  void dispose() {
    points.dispose();
    charge.dispose();
    time.dispose();
  }
}

class _AdminPointsPageState extends State<AdminPointsPage> {
  /// Subscribed here rather than through a `StreamBuilder` in [build] — see
  /// `AdminAuditPage` for why a page under [ConsoleShell] must own its
  /// subscriptions.
  StreamSubscription<PointsPolicy>? _pointsWatch;
  StreamSubscription<UrgencyPolicy>? _termsWatch;

  PointsPolicy _savedPoints = PointsPolicy.defaults;
  UrgencyPolicy _savedTerms = UrgencyPolicy.defaults;

  final Map<String, _LevelFields> _fields = {
    for (final urgency in PointsPolicy.urgencies) urgency: _LevelFields(),
  };

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final backend = ConsoleBackend.instance;
    _pointsWatch = backend.pointsPolicy.watch().listen(
      (policy) {
        if (!mounted) return;
        setState(() {
          _savedPoints = policy;
          _fillPoints(policy);
        });
      },
      onError: (Object error) => _loadFailed(error, 'The points could not be loaded.'),
    );
    _termsWatch = backend.urgencyPolicy.watch().listen(
      (terms) {
        if (!mounted) return;
        setState(() {
          _savedTerms = terms;
          _fillTerms(terms);
        });
      },
      onError: (Object error) =>
          _loadFailed(error, 'The additional charges and completion times could not be loaded.'),
    );
  }

  /// Said rather than presenting empty fields as the saved settings.
  void _loadFailed(Object error, String fallback) {
    if (!mounted) return;
    setState(() => _error = error is ApiException ? error.message : fallback);
  }

  @override
  void dispose() {
    _pointsWatch?.cancel();
    _termsWatch?.cancel();
    for (final fields in _fields.values) {
      fields.dispose();
    }
    super.dispose();
  }

  void _fillPoints(PointsPolicy policy) {
    for (final urgency in PointsPolicy.urgencies) {
      _fields[urgency]!.points.text = formatPoints(policy.pointsFor(urgency));
    }
  }

  void _fillTerms(UrgencyPolicy policy) {
    for (final urgency in PointsPolicy.urgencies) {
      final terms = policy.termsFor(urgency);
      final fields = _fields[urgency]!;
      fields.charge.text = formatPoints(terms.additionalCharge);
      fields.unit = terms.completionTime.isNone ? CompletionTimeUnit.none : terms.completionTime.unit;
      fields.time.text = terms.completionTime.isNone ? '' : '${terms.completionTime.value}';
    }
  }

  /// The points the fields describe, or null when one will not parse — which
  /// is what stops a typo being saved as zero.
  PointsPolicy? get _editedPoints {
    var next = _savedPoints;
    for (final urgency in PointsPolicy.urgencies) {
      final value = double.tryParse(_fields[urgency]!.points.text.trim());
      if (value == null || value < 0) return null;
      next = next.withPoints(urgency, value);
    }
    return next;
  }

  /// The charges and completion times the fields describe, or null when one
  /// is not valid.
  UrgencyPolicy? get _editedTerms {
    var next = _savedTerms;
    for (final urgency in PointsPolicy.urgencies) {
      final fields = _fields[urgency]!;
      final charge = double.tryParse(fields.charge.text.trim());
      if (charge == null || charge < 0) return null;
      final CompletionTime time;
      if (fields.unit == CompletionTimeUnit.none) {
        time = const CompletionTime.none();
      } else {
        final value = int.tryParse(fields.time.text.trim());
        if (value == null || value < 1) return null;
        time = CompletionTime(value, fields.unit);
      }
      next = next.withTerms(urgency, UrgencyTerms(additionalCharge: charge, completionTime: time));
    }
    return next;
  }

  /// What is wrong with the fields, worded for the admin.
  String _problem() {
    for (final urgency in PointsPolicy.urgencies) {
      final fields = _fields[urgency]!;
      final points = double.tryParse(fields.points.text.trim());
      if (points == null || points < 0) return '$urgency: points must be a number, 0 or more.';
      final charge = double.tryParse(fields.charge.text.trim());
      if (charge == null || charge < 0) return '$urgency: the additional charge must be an amount, 0 or more.';
      if (fields.unit != CompletionTimeUnit.none) {
        final value = int.tryParse(fields.time.text.trim());
        if (value == null || value < 1) {
          return '$urgency: enter the completion time as a whole number of '
              '${fields.unit.label.toLowerCase()}, 1 or more — or choose None.';
        }
      }
    }
    return 'Check the values and try again.';
  }

  bool get _dirty {
    final points = _editedPoints;
    final terms = _editedTerms;
    return points == null || terms == null || points != _savedPoints || terms != _savedTerms;
  }

  Future<void> _save() async {
    final points = _editedPoints;
    final terms = _editedTerms;
    if (points == null || terms == null) {
      setState(() => _error = _problem());
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = ConsoleBackend.instance;
    try {
      if (terms != _savedTerms) await backend.urgencyPolicy.update(terms);
      if (points != _savedPoints) await backend.pointsPolicy.update(points);
      if (mounted) showConsoleMessage(context, 'Urgency levels updated');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _error = null;
      _fillPoints(PointsPolicy.defaults);
      _fillTerms(UrgencyPolicy.defaults);
    });
  }

  void _revert() {
    setState(() {
      _error = null;
      _fillPoints(_savedPoints);
      _fillTerms(_savedTerms);
    });
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
                  _WhereSettingsGo(usesApi: ConsoleBackend.instance.usesApi),
                  SizedBox(height: context.layout.sectionSpacing),
                  for (final urgency in PointsPolicy.urgencies) ...[
                    ConsoleCard(
                      title: urgency,
                      subtitle: _summary(urgency),
                      child: _LevelEditor(
                        urgency: urgency,
                        fields: _fields[urgency]!,
                        enabled: !_busy,
                        onChanged: () => setState(() => _error = null),
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                  ],
                  ConsoleCard(
                    title: 'What a point is worth',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 17, color: ConsoleColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '1 pt = ${formatPesos(pesosPerPoint)}. Clients spend points on '
                            'additional charges; mechanics convert them to balance at the same rate.',
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
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

  /// The saved settings for [urgency] in one line: "3 pts · +₱50 · 3 days".
  String _summary(String urgency) {
    final terms = _savedTerms.termsFor(urgency);
    return '${formatPointsLabel(_savedPoints.pointsFor(urgency))} · '
        '+${formatAdditionalCharge(terms.additionalCharge)} · ${terms.completionTime.label}';
  }
}

/// One urgency level's three settings.
class _LevelEditor extends StatelessWidget {
  const _LevelEditor({
    required this.urgency,
    required this.fields,
    required this.enabled,
    required this.onChanged,
  });

  final String urgency;
  final _LevelFields fields;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasTime = fields.unit != CompletionTimeUnit.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberField(
          label: 'Points',
          helper: 'Awarded to the client and the same to the mechanic when a $urgency job is paid. '
              'Neither is shown this figure.',
          suffix: 'pts',
          controller: fields.points,
          enabled: enabled,
          onChanged: onChanged,
        ),
        _NumberField(
          label: 'Additional charge',
          helper: "Added to the client's total at checkout. ONGO revenue — never paid to the mechanic.",
          prefix: '₱',
          controller: fields.charge,
          enabled: enabled,
          onChanged: onChanged,
        ),
        // A number and a unit, the way a mechanic enters an ETA.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                key: ValueKey('$urgency-time'),
                controller: fields.time,
                enabled: enabled && hasTime,
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: 'Time completion',
                  hintText: hasTime ? 'e.g. 12' : 'No limit',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<CompletionTimeUnit>(
                // Keyed by the unit so Reset and Discard, which change it from
                // outside, show the new value.
                key: ValueKey('$urgency-unit-${fields.unit.name}'),
                initialValue: fields.unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  for (final unit in CompletionTimeUnit.values)
                    DropdownMenuItem(value: unit, child: Text(unit.label)),
                ],
                onChanged: enabled
                    ? (unit) {
                        if (unit == null) return;
                        fields.unit = unit;
                        onChanged();
                      }
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasTime
              ? 'How long the mechanic has to finish, counted from accepting the job. '
                  'Their ETA cannot be longer.'
              : 'No time limit: the ETA the mechanic quotes is the only timing the client is promised.',
          style: text.bodySmall?.copyWith(color: ConsoleColors.textMuted),
        ),
      ],
    );
  }
}

/// One editable amount.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final String label;
  final String helper;
  final String? prefix;
  final String? suffix;
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

/// Where each setting is kept, and so whether it reaches phones.
class _WhereSettingsGo extends StatelessWidget {
  const _WhereSettingsGo({required this.usesApi});

  final bool usesApi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final defaults = [
      for (final urgency in PointsPolicy.urgencies)
        '$urgency ${formatAdditionalCharge(UrgencyPolicy.defaults.termsFor(urgency).additionalCharge)} · '
            '${UrgencyPolicy.defaults.termsFor(urgency).completionTime.label.toLowerCase()}',
    ].join(', ');

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
      title: 'Where these settings go',
      child: Column(
        children: [
          line(
            usesApi ? Icons.cloud_done_outlined : Icons.computer_outlined,
            ConsoleColors.textMuted,
            usesApi
                ? 'Points are saved to the On Go API and apply on every phone.'
                : 'This is a local console build, so nothing on this page reaches a phone.',
          ),
          line(
            Icons.cloud_off_outlined,
            ConsoleColors.warning,
            'Additional charges and completion times are not stored by the On Go API yet. '
            'They are kept in this browser, and phones use the defaults ($defaults) until '
            'the backend adds them.',
          ),
        ],
      ),
    );
  }
}
