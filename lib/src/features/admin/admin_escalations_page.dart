import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../shared/request_review_dialog.dart';

/// What is waiting on the admin.
///
/// This is the admin panel's Notifications screen. It used to carry the
/// moderator activity feed as well, but every approval, rejection and
/// escalation is now written to the Audit Log — where it can be filtered by
/// who acted and opened for its full detail — so repeating it here left the
/// bell counting routine work that needed nobody's attention.
///
/// What stays is the part that genuinely needs an admin: the requests a
/// moderator escalated and cannot settle themselves.
class AdminEscalationsPage extends StatefulWidget {
  const AdminEscalationsPage({super.key});

  @override
  State<AdminEscalationsPage> createState() => _AdminEscalationsPageState();
}

class _AdminEscalationsPageState extends State<AdminEscalationsPage> {
  /// Held here rather than built in [build]: the shell swaps arrangements when
  /// the window crosses a breakpoint, and a `StreamBuilder` created in a build
  /// that does not re-run would be re-inflated onto a stream it is already
  /// listening to. Same reason as the Audit Log page.
  StreamSubscription<List<AccountVerificationRequest>>? _subscription;

  List<AccountVerificationRequest> _requests =
      const <AccountVerificationRequest>[];

  @override
  void initState() {
    super.initState();
    _subscription =
        ConsoleBackend.instance.verification.watchRequests().listen((requests) {
      if (!mounted) return;
      setState(() => _requests = requests);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escalated =
        _requests.where((r) => r.escalated && r.isPending).toList(growable: false);

    return ConsoleShell(
      child: Builder(
        builder: (context) => ListView(
          padding: consolePagePadding(context),
          children: [
            ConsoleCard(
              title: 'Waiting on you',
              subtitle: escalated.isEmpty
                  ? 'Requests a moderator flagged for an admin decision'
                  : '${escalated.length} escalated ${escalated.length == 1 ? 'request' : 'requests'}',
              padding: escalated.isEmpty
                  ? EdgeInsets.zero
                  : EdgeInsets.all(context.layout.cardPadding),
              child: escalated.isEmpty
                  ? const ConsoleEmptyState(
                      icon: Icons.flag_outlined,
                      title: 'Nothing escalated',
                      message:
                          'A moderator who is unsure about a registration can '
                          'flag it here for you to settle.',
                    )
                  : Column(
                      children: [
                        for (final request in escalated)
                          _EscalatedRow(request: request),
                      ],
                    ),
            ),
            SizedBox(height: context.layout.sectionSpacing),
            ConsoleCard(
              title: 'Everything else is in the Audit Log',
              subtitle:
                  'Approvals, rejections and escalations, filterable by who acted',
              padding: EdgeInsets.all(context.layout.cardPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    ConsoleRoutes.adminAudit,
                  ),
                  icon: const Icon(Icons.history, size: 17),
                  label: const Text('Open Audit Log'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EscalatedRow extends StatelessWidget {
  const _EscalatedRow({required this.request});

  final AccountVerificationRequest request;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final layout = context.layout;

    final identity = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: ConsoleColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flag_outlined, size: 17, color: ConsoleColors.warning),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.name, style: text.titleSmall),
              Text(
                '${request.role.label} · ${request.userNumber} · '
                'submitted ${formatConsoleDate(request.submittedAt)}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );

    final review = ElevatedButton(
      onPressed: () => showRequestReviewDialog(context, request),
      child: const Text('Review'),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ConsoleColors.warning.withValues(alpha: 0.07),
        borderRadius: ConsoleMetrics.borderRadius,
        border: Border.all(color: ConsoleColors.warning.withValues(alpha: 0.35)),
      ),
      // On a phone the Review button goes under the name rather than
      // squeezing it — a truncated name is worse than an extra row.
      child: layout.isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 14),
                review,
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                review,
              ],
            ),
    );
  }
}

