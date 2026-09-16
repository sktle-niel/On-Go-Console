import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';

/// Everything done in the console, in order: roster changes by an admin and
/// queue decisions by a moderator, in one list.
///
/// An audit log is only worth having if it cannot be edited from the screen
/// that shows it, so there is nothing here but reading and filtering. Entries
/// are written by the services as a side effect of the change itself.
class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

/// Which accounts' activity the list is showing.
enum _ActorFilter {
  all('All'),
  moderators('Moderators'),
  admin('Admin');

  const _ActorFilter(this.label);

  final String label;

  bool matches(AuditEntry entry) => switch (this) {
    _ActorFilter.all => true,
    _ActorFilter.admin => entry.isAdminActivity,
    _ActorFilter.moderators => !entry.isAdminActivity,
  };
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  _ActorFilter _filter = _ActorFilter.all;

  /// The log is subscribed to here rather than through a `StreamBuilder` in
  /// [build], and that is deliberate.
  ///
  /// `watchAuditLog()` hands back a single-subscription stream, and a
  /// `StreamBuilder` in this page's build would be created holding one
  /// particular stream. When the window crosses a breakpoint, [ConsoleShell]
  /// swaps between two different arrangements, so the page body is torn out of
  /// one element tree and re-inflated into the other — while this page itself,
  /// sitting above the shell, is never rebuilt and so never makes a fresh
  /// stream. The re-inflated builder then listens to the stream the outgoing
  /// one is still holding, because deactivated elements are not disposed of
  /// until the end of the frame, and the second listen throws
  /// "Stream has already been listened to" — the red box over the page.
  ///
  /// This state outlives every one of those rearrangements, so subscribing
  /// here means exactly one listen for the life of the page, no matter how the
  /// window is resized. It also stops the log being re-subscribed every time a
  /// filter chip is tapped.
  StreamSubscription<List<AuditEntry>>? _subscription;

  List<AuditEntry> _entries = const <AuditEntry>[];

  @override
  void initState() {
    super.initState();
    _subscription = ConsoleBackend.instance.moderators.watchAuditLog().listen((entries) {
      if (!mounted) return;
      setState(() => _entries = entries);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _entries;
    final entries = all.where(_filter.matches).toList(growable: false);

    return ConsoleShell(
      // Everything below reads the window through `context.layout`, which
      // depends on the shell's layout scope, so the padding and spacing
      // recalculate on their own whenever the window changes.
      child: Builder(
        builder: (context) {
          return ListView(
            padding: consolePagePadding(context),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _ActorFilter.values)
                    ConsoleFilterChip(
                      label: filter.label,
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                ],
              ),
              SizedBox(height: context.layout.sectionSpacing),
              ConsoleCard(
                title: entries.length == 1 ? '1 entry' : '${entries.length} entries',
                subtitle: 'Newest first',
                padding: EdgeInsets.zero,
                child: entries.isEmpty
                    ? ConsoleEmptyState(
                        icon: Icons.history,
                        title: all.isEmpty ? 'Nothing logged yet' : 'Nothing matches',
                        message: all.isEmpty
                            ? 'Roster changes and queue decisions are written here, '
                                  'with who did it, from where, and why.'
                            : 'No activity from those accounts. Try a different filter.',
                      )
                    // A phone gets one card per entry carrying the same
                    // fields. Five columns on 390 points is either unreadable
                    // or a sideways scroll nobody finds.
                    : context.layout.stacksTableRows
                        ? Padding(
                            padding: EdgeInsets.all(context.layout.cardPadding),
                            child: Column(
                              children: [
                                for (final entry in entries)
                                  _AuditCard(entry: entry),
                              ],
                            ),
                          )
                        : ConsoleHorizontalScroll(
                            minWidth: 940,
                            child: Column(
                              children: [
                                const _AuditHeader(),
                                for (final entry in entries)
                                  _AuditRow(entry: entry),
                              ],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The column widths, declared once so the header and every row line up.
class _Columns {
  const _Columns._();

  static const int when = 17;
  static const int actor = 20;
  static const int action = 20;
  static const int detail = 29;
  static const int ip = 14;
}

/// How an action reads in the ACTION column.
///
/// Derived, never stored: the log records the action, and this says what kind
/// of thing it was done to — the difference between `moderator.added` and an
/// `added` that could mean anything.
String _actionToken(AuditAction action) => switch (action) {
  AuditAction.added => 'moderator.added',
  AuditAction.removed => 'moderator.removed',
  AuditAction.promoted => 'moderator.promoted',
  AuditAction.approved => 'account.approved',
  AuditAction.rejected => 'account.rejected',
  AuditAction.escalated => 'account.escalated',
};

/// Monospace, so a column of addresses lines up digit for digit — which is the
/// only way a reader spots that two entries share one.
const List<String> _monoFallback = ['Courier New', 'monospace'];

class _AuditHeader extends StatelessWidget {
  const _AuditHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Container(
      color: ConsoleColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Expanded(flex: _Columns.when, child: Text('WHEN', style: style)),
          Expanded(flex: _Columns.actor, child: Text('ACTOR', style: style)),
          Expanded(flex: _Columns.action, child: Text('ACTION', style: style)),
          Expanded(flex: _Columns.detail, child: Text('DETAIL', style: style)),
          Expanded(flex: _Columns.ip, child: Text('IP', style: style)),
        ],
      ),
    );
  }
}

/// One entry, with everything it holds on the row.
///
/// Nothing here opens: an audit log is read by scanning it, and a detail worth
/// recording is a detail worth showing without a click.
class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorForAuditAction(entry.action);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ConsoleColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: _Columns.when,
            child: Text(
              formatConsoleDateTime(entry.occurredAt),
              style: text.bodySmall,
            ),
          ),
          Expanded(flex: _Columns.actor, child: _Actor(entry: entry)),
          Expanded(
            flex: _Columns.action,
            child: _ActionToken(action: entry.action, color: color),
          ),
          Expanded(flex: _Columns.detail, child: _Detail(entry: entry)),
          Expanded(
            flex: _Columns.ip,
            child: _IpAddress(address: entry.ipAddress),
          ),
        ],
      ),
    );
  }
}

/// Who did it, and which kind of account they hold.
class _Actor extends StatelessWidget {
  const _Actor({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.actorName,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          UserRole.fromWire(entry.actorRole).label,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// The action, in the log's own vocabulary rather than a sentence about it.
class _ActionToken extends StatelessWidget {
  const _ActionToken({required this.action, required this.color});

  final AuditAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(iconForAuditAction(action), size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _actionToken(action),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: _monoFallback,
              fontSize: 12.5,
              color: ConsoleColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// What was affected, and anything recorded about the change.
class _Detail extends StatelessWidget {
  const _Detail({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reason = entry.reason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.moderatorName,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          reason == null ? entry.role : '${entry.role} · $reason',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// The address the action came from.
class _IpAddress extends StatelessWidget {
  const _IpAddress({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    final recorded = address != null;
    return Text(
      address ?? 'Not recorded',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: recorded ? 'monospace' : null,
        fontFamilyFallback: recorded ? _monoFallback : null,
        fontSize: 12.5,
        color: recorded ? ConsoleColors.text : ConsoleColors.textMuted,
      ),
    );
  }
}

/// The same entry on a phone, where five columns do not fit.
///
/// Every field the table shows is here too — nothing is dropped for being on a
/// small screen, because the reason to open the log is the same either way.
class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorForAuditAction(entry.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: ConsoleColors.border),
        borderRadius: ConsoleMetrics.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionToken(action: entry.action, color: color),
          const SizedBox(height: 10),
          _Detail(entry: entry),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Actor(entry: entry)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatConsoleDateTime(entry.occurredAt),
                      textAlign: TextAlign.right,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    _IpAddress(address: entry.ipAddress),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
