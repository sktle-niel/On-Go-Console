import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../shared/request_review_dialog.dart';

/// The moderator's working screen: accounts waiting on a decision.
///
/// Each row can be settled inline for the common case, or opened for the
/// documents when the answer is not obvious. Actions the signed-in moderator
/// has not been granted are not offered — and are refused again by the service
/// if they are somehow submitted anyway.
class ModeratorQueuePage extends StatelessWidget {
  const ModeratorQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      child: AnimatedBuilder(
        animation: ConsoleSession.instance,
        builder: (context, _) {
          return StreamBuilder<List<AccountVerificationRequest>>(
            stream: ConsoleBackend.instance.verification.watchRequests(),
            builder: (context, snapshot) {
              final pending = (snapshot.data ?? const <AccountVerificationRequest>[])
                  .where((r) => r.isPending)
                  .toList(growable: false);

              return ListView(
                padding: consolePagePadding(context),
                children: [
                  ConsoleCard(
                    title: pending.isEmpty
                        ? 'Queue'
                        : '${pending.length} waiting',
                    subtitle: 'Registrations filed from the mobile app',
                    padding: pending.isEmpty
                        ? EdgeInsets.zero
                        : EdgeInsets.all(context.layout.cardPadding),
                    child: pending.isEmpty
                        ? const ConsoleEmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Nothing to review',
                            message:
                                'Accounts appear here when someone finishes '
                                'registration in the On Go app and their request '
                                'reaches the console.',
                          )
                        : Column(
                            children: [
                              for (final request in pending)
                                _QueueRow(request: request),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueRow extends StatefulWidget {
  const _QueueRow({required this.request});

  final AccountVerificationRequest request;

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  bool _busy = false;

  Future<void> _decide(ModerationAction action, {String? reason}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final session = ConsoleSession.instance;

    try {
      await ConsoleBackend.instance.verification.decide(
        widget.request.id,
        ModerationDecision(
          action: action,
          actorName: session.actorName,
          actorId: session.actorId,
          reason: reason,
        ),
      );
      if (mounted) {
        showConsoleMessage(context, '${widget.request.name} ${action.label}');
      }
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => _RejectDialog(name: widget.request.name),
    );
    if (reason == null) return;
    await _decide(ModerationAction.rejected, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final text = Theme.of(context).textTheme;
    final permissions = ConsoleSession.instance.permissions;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsoleColors.surface,
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(
          color: request.escalated
              ? ConsoleColors.warning.withValues(alpha: 0.5)
              : ConsoleColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ConsoleColors.surfaceMuted,
                  border: Border.all(color: ConsoleColors.border),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 22,
                  color: ConsoleColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(request.name, style: text.titleMedium),
                        ConsoleBadge(
                          label: request.role.label,
                          color: colorForAccountRole(request.role),
                        ),
                        if (request.escalated)
                          ConsoleBadge(
                            label: 'Escalated',
                            color: ConsoleColors.warning,
                            icon: Icons.flag,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${request.email} · ${request.userNumber}',
                        style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  label: 'SUBMITTED',
                  value: formatConsoleDateTime(request.submittedAt),
                ),
              ),
              Expanded(
                child: _Meta(
                  label: 'DOCUMENTS',
                  value: request.documentCount == 1
                      ? '1 file'
                      : '${request.documentCount} files',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QueueActions(
            buttons: [
              TextButton.icon(
                onPressed: () => showRequestReviewDialog(context, request),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Review documents'),
              ),
              if (permissions.canEscalate && !request.escalated)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decide(ModerationAction.escalated),
                  icon: Icon(Icons.flag_outlined, size: 16, color: ConsoleColors.warning),
                  label: Text('Escalate',
                      style: TextStyle(color: ConsoleColors.warning)),
                ),
              if (permissions.canReject)
                OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ConsoleColors.danger,
                    side: BorderSide(
                      color: ConsoleColors.danger.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              if (permissions.canApprove)
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _decide(ModerationAction.approved),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(_busy ? 'Saving…' : 'Approve'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The decision buttons under a queue card.
///
/// Right-aligned and side by side where there is room. On a phone they go
/// full width, one per row: these are the actions the whole screen exists for,
/// and a 90-point target for "Approve" on a touchscreen is not good enough.
class _QueueActions extends StatelessWidget {
  const _QueueActions({required this.buttons});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    if (!context.layout.isPhone) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: buttons,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          buttons[i],
        ],
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

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

/// Rejecting from the queue, with the reason the applicant will see.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});

  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
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
      title: Text('Reject ${widget.name}?'),
      content: SizedBox(
        width: ConsoleLayout.of(context).dialogWidth(420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The reason is shown to them in the app, so say what would need to '
              'be different.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. The ID photo is too blurry to read',
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
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
