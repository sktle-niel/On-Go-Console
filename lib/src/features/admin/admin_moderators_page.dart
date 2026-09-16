import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';

/// The moderator roster: who can sign in to this console, what each of them is
/// allowed to do, and how much they have handled.
///
/// A table rather than the app's stack of cards — this is a list an admin
/// scans and compares across, which is what a wide screen is for.
class AdminModeratorsPage extends StatelessWidget {
  const AdminModeratorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The top-bar action loses its label on a phone: "Add moderator" beside a
    // page title does not fit, and the icon on its own still reads as add.
    final compactAction = context.layout.isPhone;

    return ConsoleShell(
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: compactAction
              ? IconButton.filled(
                  tooltip: 'Add moderator',
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    ConsoleRoutes.adminAddModerator,
                  ),
                  icon: const Icon(Icons.add, size: 19),
                )
              : ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    ConsoleRoutes.adminAddModerator,
                  ),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add moderator'),
                ),
        ),
      ],
      child: StreamBuilder<List<ModeratorAccount>>(
        stream: ConsoleBackend.instance.moderators.watchModerators(),
        builder: (context, snapshot) {
          final moderators = snapshot.data ?? const <ModeratorAccount>[];
          final layout = context.layout;

          return ListView(
            padding: consolePagePadding(context),
            children: [
              ConsoleCard(
                title: moderators.length == 1
                    ? '1 moderator'
                    : '${moderators.length} moderators',
                subtitle: 'Accounts that can sign in to this console',
                padding: EdgeInsets.zero,
                child: moderators.isEmpty
                    ? const ConsoleEmptyState(
                        icon: Icons.shield_outlined,
                        title: 'No moderators yet',
                        message:
                            'Add the first one and they can start clearing the '
                            'verification queue.',
                      )
                    // A phone gets one card per moderator. The same fields and
                    // the same two actions — a table squeezed onto 390 points
                    // is either unreadable or a sideways scroll nobody finds.
                    : layout.stacksTableRows
                        ? Padding(
                            padding: EdgeInsets.all(layout.cardPadding),
                            child: Column(
                              children: [
                                for (final moderator in moderators)
                                  _RosterCard(moderator: moderator),
                              ],
                            ),
                          )
                        : ConsoleHorizontalScroll(
                            minWidth: 820,
                            child: Column(
                              children: [
                                const _RosterHeader(),
                                for (final moderator in moderators)
                                  _RosterRow(moderator: moderator),
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

  static const int person = 32;
  static const int permissions = 26;
  static const int added = 15;
  static const int handled = 10;
  static const int actions = 17;
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Container(
      color: ConsoleColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Expanded(flex: _Columns.person, child: Text('MODERATOR', style: style)),
          Expanded(flex: _Columns.permissions, child: Text('PERMISSIONS', style: style)),
          Expanded(flex: _Columns.added, child: Text('ADDED', style: style)),
          Expanded(
            flex: _Columns.handled,
            child: Text('HANDLED', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: _Columns.actions,
            child: Text('', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// The two actions on a moderator, shared by the table row and the phone card
/// so both do exactly the same thing.
mixin _RosterActions {
  ModeratorAccount get moderator;

  Future<void> _editPermissions(BuildContext context) async {
    final updated = await showDialog<ModeratorPermissions>(
      context: context,
      builder: (ctx) => _PermissionsDialog(moderator: moderator),
    );
    if (updated == null || !context.mounted) return;

    try {
      await ConsoleBackend.instance.moderators
          .updatePermissions(moderator.id, updated);
      if (context.mounted) {
        showConsoleMessage(context, 'Permissions updated for ${moderator.name}');
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showConsoleMessage(context, error.message, isError: true);
      }
    }
  }

  Future<void> _remove(BuildContext context) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => _RemoveModeratorDialog(name: moderator.name),
    );
    if (reason == null || !context.mounted) return;

    try {
      await ConsoleBackend.instance.moderators.removeModerator(
        moderator.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (context.mounted) {
        showConsoleMessage(context, '${moderator.name} removed');
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showConsoleMessage(context, error.message, isError: true);
      }
    }
  }

  /// The moderator's profile photo, when the local directory is holding one.
  ImageProvider? photoFor(ModeratorAccount moderator) {
    final bytes =
        ConsoleBackend.instance.localModerators?.photoBytesFor(moderator.id);
    return bytes == null ? null : MemoryImage(bytes);
  }
}

/// One moderator as a table row — the tablet and desktop arrangement.
class _RosterRow extends StatelessWidget with _RosterActions {
  const _RosterRow({required this.moderator});

  @override
  final ModeratorAccount moderator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ConsoleColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: _Columns.person,
            child: Row(
              children: [
                ConsoleAvatar(
                  initials: moderator.initials,
                  radius: 18,
                  image: photoFor(moderator),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              moderator.name,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConsoleBadge(
                            label: moderator.status.label,
                            color: moderator.isActive
                                ? ConsoleColors.success
                                : ConsoleColors.textMuted,
                          ),
                        ],
                      ),
                      Text(
                        moderator.email,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _Columns.permissions,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PermissionPip(
                  label: 'Approve',
                  granted: moderator.permissions.canApprove,
                  color: ConsoleColors.success,
                ),
                _PermissionPip(
                  label: 'Reject',
                  granted: moderator.permissions.canReject,
                  color: ConsoleColors.danger,
                ),
                _PermissionPip(
                  label: 'Escalate',
                  granted: moderator.permissions.canEscalate,
                  color: ConsoleColors.warning,
                ),
                _PermissionPip(
                  label: 'Background',
                  granted: moderator.permissions.canChangeBackground,
                  color: ConsoleColors.info,
                ),
              ],
            ),
          ),
          Expanded(
            flex: _Columns.added,
            child: Text(formatConsoleDate(moderator.addedAt), style: text.bodySmall),
          ),
          Expanded(
            flex: _Columns.handled,
            child: Text(
              '${moderator.actionsHandled}',
              textAlign: TextAlign.right,
              style: text.titleSmall,
            ),
          ),
          Expanded(
            flex: _Columns.actions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _editPermissions(context),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _remove(context),
                  style: TextButton.styleFrom(foregroundColor: ConsoleColors.danger),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One moderator as a card — the phone arrangement.
///
/// Every field the table row shows, laid out down the screen instead of
/// across it, and the same Edit and Remove actions. Nothing is dropped: an
/// admin on a phone can do everything an admin at a desk can.
class _RosterCard extends StatelessWidget with _RosterActions {
  const _RosterCard({required this.moderator});

  @override
  final ModeratorAccount moderator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ConsoleColors.surfaceMuted,
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConsoleAvatar(
                initials: moderator.initials,
                radius: 20,
                image: photoFor(moderator),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            moderator.name,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConsoleBadge(
                          label: moderator.status.label,
                          color: moderator.isActive
                              ? ConsoleColors.success
                              : ConsoleColors.textMuted,
                        ),
                      ],
                    ),
                    Text(
                      moderator.email,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CardMeta(
                  label: 'ADDED',
                  value: formatConsoleDate(moderator.addedAt),
                ),
              ),
              Expanded(
                child: _CardMeta(
                  label: 'HANDLED',
                  value: '${moderator.actionsHandled}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConsoleSectionLabel('Permissions', padding: EdgeInsets.only(bottom: 8)),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _PermissionPip(
                label: 'Approve',
                granted: moderator.permissions.canApprove,
                color: ConsoleColors.success,
              ),
              _PermissionPip(
                label: 'Reject',
                granted: moderator.permissions.canReject,
                color: ConsoleColors.danger,
              ),
              _PermissionPip(
                label: 'Escalate',
                granted: moderator.permissions.canEscalate,
                color: ConsoleColors.warning,
              ),
              _PermissionPip(
                label: 'Background',
                granted: moderator.permissions.canChangeBackground,
                color: ConsoleColors.info,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _editPermissions(context),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _remove(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ConsoleColors.danger,
                    side: BorderSide(
                      color: ConsoleColors.danger.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A label-over-value pair inside a roster card, standing in for a table cell.
class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}

/// A granted or withheld permission, compact enough to sit four to a cell.
class _PermissionPip extends StatelessWidget {
  const _PermissionPip({
    required this.label,
    required this.granted,
    required this.color,
  });

  final String label;
  final bool granted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shown = granted ? color : ConsoleColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.remove_circle_outline,
          size: 13,
          color: shown.withValues(alpha: granted ? 1 : 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: shown.withValues(alpha: granted ? 1 : 0.6),
            fontWeight: granted ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Editing what one moderator may do.
class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.moderator});

  final ModeratorAccount moderator;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late ModeratorPermissions _permissions = widget.moderator.permissions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: consoleDialogInsets(context),
      title: Text('${widget.moderator.name}’s permissions'),
      content: SizedBox(
        width: ConsoleLayout.of(context).dialogWidth(440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConsoleToggleRow(
                title: 'Approve accounts',
                subtitle: 'Grants a registered account access to the platform',
                value: _permissions.canApprove,
                onChanged: (v) =>
                    setState(() => _permissions = _permissions.copyWith(canApprove: v)),
              ),
              Divider(height: 1, color: ConsoleColors.border),
              ConsoleToggleRow(
                title: 'Reject accounts',
                subtitle: 'Declines a registration, with a reason',
                value: _permissions.canReject,
                onChanged: (v) =>
                    setState(() => _permissions = _permissions.copyWith(canReject: v)),
              ),
              Divider(height: 1, color: ConsoleColors.border),
              ConsoleToggleRow(
                title: 'Escalate to admin',
                subtitle: 'Flags a request for you to settle',
                value: _permissions.canEscalate,
                onChanged: (v) =>
                    setState(() => _permissions = _permissions.copyWith(canEscalate: v)),
              ),
              Divider(height: 1, color: ConsoleColors.border),
              ConsoleToggleRow(
                title: 'Change the app background',
                subtitle: "Sets the mobile app's Sign In and Welcome photo",
                value: _permissions.canChangeBackground,
                onChanged: (v) => setState(
                  () => _permissions = _permissions.copyWith(canChangeBackground: v),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: ConsoleColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _permissions),
          child: const Text('Save permissions'),
        ),
      ],
    );
  }
}

/// Removing a moderator, with the reason that goes on the audit entry.
class _RemoveModeratorDialog extends StatefulWidget {
  const _RemoveModeratorDialog({required this.name});

  final String name;

  @override
  State<_RemoveModeratorDialog> createState() => _RemoveModeratorDialogState();
}

class _RemoveModeratorDialogState extends State<_RemoveModeratorDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: consoleDialogInsets(context),
      title: Text('Remove ${widget.name}?'),
      content: SizedBox(
        width: ConsoleLayout.of(context).dialogWidth(400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'They lose access to the console immediately. Requests they have '
              'already decided are unaffected.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Recorded on the audit entry',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: ConsoleColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ConsoleColors.danger),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Remove'),
        ),
      ],
    );
  }
}
