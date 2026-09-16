import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../shared/request_review_dialog.dart';

/// The accounts that made it through: who is live on the platform.
///
/// A directory rather than a work list — nothing here needs a decision, so
/// there are no actions on the rows, only a way to look one up.
class ModeratorAccountsPage extends StatefulWidget {
  const ModeratorAccountsPage({super.key});

  @override
  State<ModeratorAccountsPage> createState() => _ModeratorAccountsPageState();
}

class _ModeratorAccountsPageState extends State<ModeratorAccountsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      child: StreamBuilder<List<AccountVerificationRequest>>(
        stream: ConsoleBackend.instance.verification.watchRequests(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <AccountVerificationRequest>[];
          final approved = LocalVerificationService.filterRequests(
            all,
            status: ApprovalStatus.approved,
            search: _search.text,
          );
          final anyApproved =
              all.any((r) => r.status == ApprovalStatus.approved);

          return ListView(
            padding: consolePagePadding(context),
            children: [
              // Fixed width on a wide window so the field does not stretch to
              // a thousand points; full width once there is not that to spare.
              SizedBox(
                width: context.layout.stacksPairs ? double.infinity : 340,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search accounts',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              SizedBox(height: context.layout.sectionSpacing),
              ConsoleCard(
                title: approved.length == 1
                    ? '1 account'
                    : '${approved.length} accounts',
                subtitle: 'Approved and active on the platform',
                padding: approved.isEmpty
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(vertical: 4),
                child: approved.isEmpty
                    ? ConsoleEmptyState(
                        icon: Icons.people_outline,
                        title: anyApproved
                            ? 'Nothing matches'
                            : 'No approved accounts yet',
                        message: anyApproved
                            ? 'No account matches that search.'
                            : 'Accounts you approve from the queue are listed here.',
                      )
                    : Column(
                        children: [
                          for (final account in approved)
                            _AccountRow(request: account),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.request});

  final AccountVerificationRequest request;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => showRequestReviewDialog(context, request),
      borderRadius: ConsoleMetrics.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ConsoleColors.surfaceMuted,
                border: Border.all(color: ConsoleColors.border),
              ),
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: ConsoleColors.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.name,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall,
                        ),
                      ),
                      ConsoleBadge(
                        label: request.role.label,
                        color: colorForAccountRole(request.role),
                      ),
                      const SizedBox(width: 6),
                      ConsoleBadge(label: 'active', color: ConsoleColors.success),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.email} · ${request.userNumber} · approved '
                    '${formatConsoleDate(request.reviewedAt ?? request.submittedAt)}',
                    style: text.bodySmall,
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
