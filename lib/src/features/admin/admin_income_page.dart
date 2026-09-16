import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';
import '../../widgets/revenue_charts.dart';

/// What the platform has earned.
///
/// Read-only, and it has to be: the console cannot book a peso. Every figure
/// here came from the mobile app reporting a payment that a client actually
/// completed, which is the whole reason [PlatformRevenueApi] has a write side
/// on one surface and a read side on the other.
class AdminIncomePage extends StatelessWidget {
  const AdminIncomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return ConsoleShell(
      child: StreamBuilder<PlatformRevenueSummary>(
        stream: ConsoleBackend.instance.revenue.watchSummary(),
        builder: (context, snapshot) {
          final revenue = snapshot.data ?? const PlatformRevenueSummary();
          // The Yearly Revenue chart plots whole years, totalled from the same
          // monthly ledger the Overview's chart draws — never a second set of
          // figures.
          final years = revenue.yearlyTotals;
          final thisYear = revenue.revenueForYear(year);
          final transactions = revenue.transactionsForYear(year);
          final trend = revenueTrend(
            thisYear: thisYear,
            lastYear: revenue.revenueForYear(year - 1),
            year: year,
          );

          return ListView(
            padding: consolePagePadding(context),
            children: [
              // Side by side even on a phone, as the Income tab had them.
              ConsoleResponsiveGrid(
                columns: 2,
                // Both the same size. Their footnotes are different lengths —
                // one is a trend, the other a sentence explaining where the
                // figure comes from — and without this the taller one makes
                // the pair look misaligned rather than related.
                stretchRows: true,
                children: [
                  ConsoleStatTile(
                    icon: Icons.payments_outlined,
                    accent: ConsoleColors.success,
                    value: formatPeso(thisYear),
                    label: 'YTD Revenue',
                    footnote: trend?.label ?? revenueSourceNote(year),
                    footnoteColor: trend == null
                        ? null
                        : trend.positive
                            ? ConsoleColors.success
                            : ConsoleColors.danger,
                  ),
                  ConsoleStatTile(
                    icon: Icons.receipt_long_outlined,
                    accent: ConsoleColors.info,
                    value: '$transactions',
                    label: 'Transactions',
                    footnote: transactions == 1
                        ? '1 completed payment'
                        : '$transactions completed payments',
                  ),
                ],
              ),
              if (revenue.priorityFeeCount > 0) ...[
                const SizedBox(height: 16),
                _PriorityFeeNote(
                  amount: revenue.priorityFeeRevenue,
                  count: revenue.priorityFeeCount,
                ),
              ],
              SizedBox(height: context.layout.sectionSpacing),
              ConsoleCard(
                title: 'Yearly Revenue',
                subtitle: years.length == 1
                    ? 'Platform fees booked in ${years.single.year}, by urgency'
                    : 'Platform fees booked per year, by urgency',
                trailing: years.isEmpty
                    ? null
                    : Text(
                        years.length == 1
                            ? '1 year'
                            : '${years.first.year}–${years.last.year}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                child: years.isEmpty
                    ? RevenueEmptyChart(
                        height: context.layout.chartHeight,
                        message:
                            'Years appear here as the mobile app reports client payments.',
                      )
                    : RevenueBarChart(
                        periods: years,
                        height: context.layout.chartHeight,
                      ),
              ),
              SizedBox(height: context.layout.sectionSpacing),
              ConsoleCard(
                title: 'Transactions by urgency',
                subtitle: 'Completed payments in $year, and each urgency\'s share',
                child: transactions == 0
                    ? const ConsoleEmptyState(
                        icon: Icons.donut_large_outlined,
                        title: 'No payments this year',
                        message:
                            'Each ring fills as the mobile app reports Normal, Urgent '
                            'and Emergency payments.',
                      )
                    : RevenueUrgencyRings(revenue: revenue, year: year),
              ),
              // No monthly table here. The Overview's Monthly Revenue chart
              // already breaks the year down month by month, and does it
              // better — it reads each month's total, its payment count and
              // its split by urgency out of the same ledger, under a pointer.
              // A second list of the same months was one more thing to keep in
              // step for no extra answer.
            ],
          );
        },
      ),
    );
  }
}

class _PriorityFeeNote extends StatelessWidget {
  const _PriorityFeeNote({required this.amount, required this.count});

  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsoleColors.success.withValues(alpha: 0.07),
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, size: 18, color: ConsoleColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₱${amount.toStringAsFixed(0)} from priority fees',
                  style: text.titleSmall?.copyWith(color: ConsoleColors.success),
                ),
                const SizedBox(height: 3),
                Text(
                  '$count paid ${count == 1 ? 'job' : 'jobs'} carried an Urgent '
                  '(+₱50) or Emergency (+₱100) charge. Already counted in the '
                  'totals above.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
