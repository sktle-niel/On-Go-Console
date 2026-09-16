import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../shared/request_review_dialog.dart';

/// Everything already decided, so a moderator can look up what happened to an
/// account and why.
class ModeratorHistoryPage extends StatefulWidget {
  const ModeratorHistoryPage({super.key});

  @override
  State<ModeratorHistoryPage> createState() => _ModeratorHistoryPageState();
}

class _ModeratorHistoryPageState extends State<ModeratorHistoryPage> {
  ApprovalStatus? _filter;
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
          final decided =
              all.where((r) => !r.isPending).toList(growable: false);
          final entries = LocalVerificationService.filterRequests(
            decided,
            status: _filter,
            search: _search.text,
          )..sort((a, b) => (b.reviewedAt ?? b.submittedAt)
              .compareTo(a.reviewedAt ?? a.submittedAt));

          return ListView(
            padding: consolePagePadding(context),
            children: [
              Builder(
                builder: (context) {
                  final layout = context.layout;
                  final filters = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ConsoleFilterChip(
                        label: 'All',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      ConsoleFilterChip(
                        label: 'Approved',
                        selected: _filter == ApprovalStatus.approved,
                        onTap: () =>
                            setState(() => _filter = ApprovalStatus.approved),
                      ),
                      ConsoleFilterChip(
                        label: 'Rejected',
                        selected: _filter == ApprovalStatus.rejected,
                        onTap: () =>
                            setState(() => _filter = ApprovalStatus.rejected),
                      ),
                    ],
                  );
                  // The search box keeps a fixed width beside the filters on a
                  // wide window, and spans the row once they stack.
                  final field = TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: layout.isPhone
                          ? 'Search records'
                          : 'Search name, email or user number',
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                  );

                  if (layout.stacksPairs) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: filters),
                        const SizedBox(height: 12),
                        field,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: filters),
                      SizedBox(width: 280, child: field),
                    ],
                  );
                },
              ),
              SizedBox(height: context.layout.sectionSpacing),
              ConsoleCard(
                title: entries.length == 1
                    ? '1 record'
                    : '${entries.length} records',
                subtitle: 'Most recently decided first',
                padding: entries.isEmpty
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(vertical: 4),
                child: entries.isEmpty
                    ? ConsoleEmptyState(
                        icon: Icons.history,
                        title: decided.isEmpty
                            ? 'Nothing decided yet'
                            : 'Nothing matches',
                        message: decided.isEmpty
                            ? 'Requests you approve or reject move here, with the '
                                'reason and who decided them.'
                            : 'Try a different filter or search.',
                      )
                    : Column(
                        children: [
                          for (final request in entries)
                            _HistoryRow(request: request),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.request});

  final AccountVerificationRequest request;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorForApproval(request.status);

    return InkWell(
      onTap: () => showRequestReviewDialog(context, request),
      borderRadius: ConsoleMetrics.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.13),
              ),
              child: Icon(
                request.status == ApprovalStatus.approved ? Icons.check : Icons.close,
                size: 16,
                color: color,
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
                      ConsoleBadge(label: request.status.label, color: color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.role.label} · ${request.userNumber} · '
                    'by ${request.reviewerName ?? '—'} · '
                    '${formatConsoleDateTime(request.reviewedAt ?? request.submittedAt)}',
                    style: text.bodySmall,
                  ),
                  if (request.reason != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      request.reason!,
                      style: text.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
