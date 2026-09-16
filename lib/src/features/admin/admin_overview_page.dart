import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../../widgets/revenue_charts.dart';

/// The admin's landing page: how the platform is doing right now.
///
/// Four figures, the revenue curve, and who is doing the reviewing. Every one
/// of them is read through the API rather than computed here, because none of
/// this data is the console's — the queue belongs to the moderation service,
/// the revenue to whatever booked the payments.
class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = ConsoleBackend.instance;

    return ConsoleShell(
      child: ListView(
        padding: consolePagePadding(context),
        children: [
          StreamBuilder<List<AccountVerificationRequest>>(
            stream: backend.verification.watchRequests(),
            builder: (context, requestSnapshot) {
              final requests = requestSnapshot.data ?? const <AccountVerificationRequest>[];
              return StreamBuilder<List<ModeratorAccount>>(
                stream: backend.moderators.watchModerators(),
                builder: (context, moderatorSnapshot) {
                  final moderators =
                      moderatorSnapshot.data ?? const <ModeratorAccount>[];
                  return StreamBuilder<PlatformRevenueSummary>(
                    stream: backend.revenue.watchSummary(),
                    builder: (context, revenueSnapshot) {
                      final revenue =
                          revenueSnapshot.data ?? const PlatformRevenueSummary();
                      return _body(context, requests, moderators, revenue);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<AccountVerificationRequest> requests,
    List<ModeratorAccount> moderators,
    PlatformRevenueSummary revenue,
  ) {
    final pending = requests.where((r) => r.isPending).length;
    final approved =
        requests.where((r) => r.status == ApprovalStatus.approved).length;
    final activeMods = moderators.where((m) => m.isActive).length;
    // This card is the year to date and says so, so it plots this year's
    // months. A ledger carrying earlier years belongs to Income's Yearly
    // Revenue chart, not to a twenty-one-month curve here.
    final year = DateTime.now().year;
    final months = revenue.months.where((m) => m.year == year).toList();
    final latest = months.isEmpty ? null : months.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The Admin panel's four figures, in its own order and its own words.
        _StatGrid(
          tiles: [
            ConsoleStatTile(
              icon: Icons.groups,
              accent: ConsoleColors.info,
              value: '$activeMods',
              label: 'Active Mods',
            ),
            ConsoleStatTile(
              icon: Icons.watch_later_outlined,
              accent: ConsoleColors.warning,
              value: '$pending',
              label: 'Queue',
            ),
            ConsoleStatTile(
              icon: Icons.attach_money,
              accent: ConsoleColors.success,
              value: latest == null ? '₱0' : formatPeso(latest.revenue),
              label: 'Monthly Revenue',
              footnote: latest == null ? null : '${latest.month} ${latest.year}',
            ),
            ConsoleStatTile(
              icon: Icons.check_circle_outline,
              accent: ConsoleColors.danger,
              value: '$approved',
              label: 'Accounts',
            ),
          ],
        ),
        SizedBox(height: context.layout.sectionSpacing),
        ConsoleCard(
          title: 'Monthly Revenue',
          subtitle: context.layout.isPhone
              ? null
              : (months.isEmpty
                  ? 'Platform fees, as the mobile app reports them'
                  : 'Normal, Urgent and Emergency, month by month'),
          trailing: Text('YTD', style: Theme.of(context).textTheme.labelSmall),
          child: months.isEmpty
              ? RevenueEmptyChart(
                  height: context.layout.chartHeight,
                  message:
                      'Payments booked by the mobile app appear here once the API connects the two.',
                )
              : RevenueLineChart(
                  income: months,
                  height: context.layout.chartHeight,
                ),
        ),
        SizedBox(height: context.layout.sectionSpacing),
        ConsoleCard(
          title: context.layout.isPhone
              ? 'MODERATOR THROUGHPUT'
              : 'Moderator throughput',
          subtitle: context.layout.isPhone
              ? null
              : 'Requests each moderator has approved, rejected or escalated',
          child: _Throughput(moderators: moderators),
        ),
      ],
    );
  }
}

/// The stat tiles: four across on a desktop, 2×2 on a tablet or a phone. The
/// column count comes from the device rather than from a width guess made
/// here, so it agrees with every other grid in the console.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return ConsoleResponsiveGrid(
      columns: context.layout.statColumns,
      // All four the same size, whatever is in them. Monthly Revenue carries a
      // period under its label and the other three carry nothing, which left
      // it standing taller than its neighbours on a desktop and taller than
      // the card beside it in the phone's 2×2 block.
      stretchRows: true,
      children: tiles,
    );
  }
}

class _Throughput extends StatelessWidget {
  const _Throughput({required this.moderators});

  final List<ModeratorAccount> moderators;

  @override
  Widget build(BuildContext context) {
    if (moderators.isEmpty) {
      return const ConsoleEmptyState(
        icon: Icons.shield_outlined,
        title: 'No moderators yet',
        message: 'Add one from Add Moderator and their throughput shows up here.',
      );
    }

    final ranked = [...moderators]
      ..sort((a, b) => b.actionsHandled.compareTo(a.actionsHandled));
    final busiest = ranked.first.actionsHandled;

    return Column(
      children: [
        for (final moderator in ranked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ConsoleAvatar(initials: moderator.initials, radius: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moderator.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: busiest == 0 ? 0 : moderator.actionsHandled / busiest,
                          minHeight: 6,
                          backgroundColor: ConsoleColors.border,
                          valueColor: AlwaysStoppedAnimation(ConsoleColors.brand),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${moderator.actionsHandled}',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
