import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../../widgets/credential_views.dart';

/// The one place a verification request is decided.
///
/// Shared by the moderator queue and the admin's escalations screen, because
/// they are the same decision made by different people — and a second copy of
/// this would be a second place for the rules to drift.
///
/// The dialog submits through [AccountVerificationApi.decide] and reports
/// whatever comes back. It does not pre-judge permissions beyond hiding
/// buttons the session cannot use: the service checks them again, and an error
/// from there is shown here rather than swallowed.
Future<void> showRequestReviewDialog(
  BuildContext context,
  AccountVerificationRequest request,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _RequestReviewDialog(request: request),
  );
}

class _RequestReviewDialog extends StatefulWidget {
  const _RequestReviewDialog({required this.request});

  final AccountVerificationRequest request;

  @override
  State<_RequestReviewDialog> createState() => _RequestReviewDialogState();
}

class _RequestReviewDialogState extends State<_RequestReviewDialog> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(ModerationAction action) async {
    if (_busy) return;

    if (action == ModerationAction.rejected && _reason.text.trim().isEmpty) {
      final confirmed = await confirmConsoleAction(
        context,
        title: 'Reject without a reason?',
        message:
            'The applicant sees the reason in the app. Rejecting with none '
            'recorded is logged as "No reason given".',
        confirmLabel: 'Reject anyway',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    final session = ConsoleSession.instance;

    try {
      await ConsoleBackend.instance.verification.decide(
        widget.request.id,
        ModerationDecision(
          action: action,
          actorName: session.actorName,
          actorId: session.actorId,
          reason: _reason.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showConsoleMessage(
        context,
        '${widget.request.name} ${action.label}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showConsoleMessage(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final permissions = ConsoleSession.instance.permissions;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      insetPadding: consoleDialogInsets(context),
      title: Row(
        children: [
          Expanded(child: Text(request.name)),
          ConsoleBadge(
            label: request.status.label,
            color: colorForApproval(request.status),
          ),
          if (request.escalated) ...[
            const SizedBox(width: 6),
            ConsoleBadge(
              label: 'Escalated',
              color: ConsoleColors.warning,
              icon: Icons.flag,
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: ConsoleLayout.of(context).dialogWidth(520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(request.email, style: text.bodySmall),
                  Text(request.userNumber, style: text.bodySmall),
                  Text(request.role.label, style: text.bodySmall),
                  Text(
                    'Submitted ${formatConsoleDateTime(request.submittedAt)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ConsoleSectionLabel('Documents (${request.documentCount})'),
              RequestDocumentsView(request: request),
              const SizedBox(height: 12),
              if (request.isPending) ...[
                ConsoleSectionLabel('Decision'),
                TextField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Reason, if you are rejecting this account',
                  ),
                ),
              ] else ...[
                ConsoleSectionLabel('Outcome'),
                ConsoleField(
                  label: request.status.label,
                  value: request.reviewedAt == null
                      ? 'Reviewed by ${request.reviewerName ?? '—'}'
                      : '${request.reviewerName ?? '—'} · '
                          '${formatConsoleDateTime(request.reviewedAt!)}',
                ),
                if (request.reason != null)
                  ConsoleField(label: 'Reason', value: request.reason!),
              ],
            ],
          ),
        ),
      ),
      actions: request.isPending
          ? [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: ConsoleColors.textMuted)),
              ),
              if (permissions.canEscalate && !request.escalated)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decide(ModerationAction.escalated),
                  icon: Icon(Icons.flag_outlined, size: 16, color: ConsoleColors.warning),
                  label: Text(
                    'Escalate',
                    style: TextStyle(color: ConsoleColors.warning),
                  ),
                ),
              if (permissions.canReject)
                OutlinedButton(
                  onPressed: _busy ? null : () => _decide(ModerationAction.rejected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ConsoleColors.danger,
                    side: BorderSide(color: ConsoleColors.danger.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Reject'),
                ),
              if (permissions.canApprove)
                ElevatedButton(
                  onPressed: _busy ? null : () => _decide(ModerationAction.approved),
                  child: Text(_busy ? 'Saving…' : 'Approve'),
                ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
    );
  }
}
