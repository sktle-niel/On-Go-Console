import 'package:on_go_shared/on_go_shared.dart';

import 'live_value.dart';

/// The platform revenue ledger, as this console holds it.
///
/// The console is the read side of [PlatformRevenueApi]: it renders the Admin
/// Overview and Income screens from [fetchSummary] and [watchSummary]. The
/// write side belongs to the mobile app, which reports a payment when a client
/// actually pays, so [reportCompletedPayment] is refused here — a console
/// cannot book revenue nobody collected.
///
/// The ledger therefore starts empty and stays empty until reports arrive over
/// the API. Nothing is seeded: every peso in the Admin charts has to be a
/// payment that really went through, the same rule the panel this replaced had.
class LocalRevenueService implements PlatformRevenueApi {
  final LiveValue<PlatformRevenueSummary> _summary =
      LiveValue(const PlatformRevenueSummary());

  @override
  Future<PlatformRevenueSummary> fetchSummary() async => _summary.value;

  @override
  Stream<PlatformRevenueSummary> watchSummary() => _summary.stream;

  @override
  Future<void> reportCompletedPayment(CompletedPaymentReport payment) {
    throw const ApiException(
      ApiErrorKind.forbidden,
      'Payments are reported by the On Go mobile app when a client pays.',
    );
  }
}
