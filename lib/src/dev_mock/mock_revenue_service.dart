import 'package:on_go_shared/on_go_shared.dart';

import 'package:on_go_console_backend/local/live_value.dart';
import 'mock_revenue_data.dart';

/// FAKE DATA — UI TESTING ONLY. Delete `lib/src/dev_mock/` to remove it.
///
/// A [PlatformRevenueApi] that serves [buildMockRevenueSummary] instead of an
/// empty ledger. It is a drop-in for `LocalRevenueService`: same contract,
/// same replay-on-subscribe stream, so the Overview and Income screens are the
/// unmodified production widgets reading an unmodified production API — only
/// the numbers underneath are invented.
///
/// Unlike the local service this one accepts [reportCompletedPayment], because
/// refusing it here would prove nothing: the rule that a console cannot book a
/// peso belongs to the real implementation, and a mock enforcing it would only
/// stop somebody from watching the charts move.
class MockRevenueService implements PlatformRevenueApi {
  MockRevenueService({DateTime? asOf, bool? includePriorYear})
      : _summary = LiveValue(buildMockRevenueSummary(
          asOf: asOf,
          includePriorYear: includePriorYear ?? kMockRevenueIncludesPriorYear,
        ));

  final LiveValue<PlatformRevenueSummary> _summary;

  /// Jobs already booked, so a repeated report is ignored rather than counted
  /// twice — the same idempotency the real API promises.
  final Set<String> _bookedRequests = <String>{};

  @override
  Future<PlatformRevenueSummary> fetchSummary() async => _summary.value;

  @override
  Stream<PlatformRevenueSummary> watchSummary() => _summary.stream;

  @override
  Future<void> reportCompletedPayment(CompletedPaymentReport payment) async {
    if (!_bookedRequests.add(payment.requestId)) return;

    final current = _summary.value;
    final label = revenueMonthLabelFor(payment.paidAt);
    final year = payment.paidAt.year;
    var matched = false;

    final months = [
      for (final month in current.months)
        if (month.month == label && month.year == year)
          () {
            matched = true;
            return month.addPayment(fee: payment.platformFee, urgency: payment.urgency);
          }()
        else
          month,
    ];

    if (!matched) {
      months.add(MonthlyIncome(
        month: label,
        year: year,
        revenue: payment.platformFee,
        transactions: 1,
        byUrgency: {
          payment.urgency:
              UrgencyTotals(revenue: payment.platformFee, transactions: 1),
        },
      ));
      months.sort((a, b) => a.year == b.year
          ? a.monthNumber.compareTo(b.monthNumber)
          : a.year.compareTo(b.year));
    }

    _summary.set(PlatformRevenueSummary(
      months: List.unmodifiable(months),
      priorityFeeRevenue: current.priorityFeeRevenue + payment.platformFee,
      priorityFeeCount: current.priorityFeeCount + (payment.platformFee > 0 ? 1 : 0),
    ));
  }
}
