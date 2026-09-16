import 'package:on_go_shared/on_go_shared.dart';

/// FAKE DATA — UI TESTING ONLY. Delete `lib/src/dev_mock/` to remove it.
///
/// The shape of a plausible year of On Go platform revenue, so the Admin
/// Overview and Income screens can be looked at with something in them. None
/// of this was collected from anybody: it is a hand-written curve, turned into
/// [PlatformRevenueSummary] by [buildMockRevenueSummary].
///
/// It is deterministic on purpose. A hot reload, a route change and a rebuild
/// all produce the identical ledger, so a chart that moves between two frames
/// moved because of the widget, not because of the data.

/// Whether the mock ledger also carries the previous calendar year.
///
/// On by default now that the Income screen plots Yearly Revenue: a ledger of
/// one year draws a single bar there, which says nothing about the shape of
/// the chart. It also feeds the year-on-year chip (`+19% vs 2025`), the other
/// thing a single year cannot show.
///
/// Safe for the Overview, which scopes itself to the current year rather than
/// plotting every month it is handed. Turn it off to see either screen with a
/// brand-new platform's single year of history.
const bool kMockRevenueIncludesPriorYear = true;

/// Whether the month in progress is cut down to the part of it that has passed.
///
/// On by default, because that is what a real dashboard looks like mid-month —
/// and because it puts a fall at the right-hand end of both charts, which is
/// the half of the drawing a rising curve never exercises. Turn it off to see
/// the newest month at full height instead.
const bool kMockProratesCurrentMonth = true;

/// What the platform books per completed payment, in pesos.
///
/// The split matters to the UI, not just to the total: the Income screen
/// breaks the priority share back out of the revenue in its own note, so the
/// two figures have to be derived from one set of numbers rather than invented
/// separately.
const double mockBasePlatformFee = 25;
const double mockUrgentFee = 50;
const double mockEmergencyFee = 100;

/// How much smaller the platform was a year ago, as a fraction of [kMockYearShape].
const double mockPriorYearScale = 0.55;

/// The floor applied to the month in progress, as a fraction of a full month.
///
/// A run on the 1st would otherwise prorate the newest month to nearly zero
/// and the newest point on the curve would look like an outage rather than a
/// month that has barely started.
const double mockCurrentMonthFloor = 0.2;

/// One month of activity, before any proration.
class MockMonthProfile {
  /// Completed client payments, fee-bearing or not.
  final int transactions;

  /// How many of those carried an Urgent (+P50) charge.
  final int urgentJobs;

  /// How many carried an Emergency (+P100) charge.
  final int emergencyJobs;

  const MockMonthProfile({
    required this.transactions,
    required this.urgentJobs,
    required this.emergencyJobs,
  });

  MockMonthProfile scaled(double factor) => MockMonthProfile(
        transactions: (transactions * factor).round().clamp(1, 1 << 30),
        urgentJobs: (urgentJobs * factor).round(),
        emergencyJobs: (emergencyJobs * factor).round(),
      );

  double get priorityFees => urgentJobs * mockUrgentFee + emergencyJobs * mockEmergencyFee;

  double get revenue => transactions * mockBasePlatformFee + priorityFees;

  int get priorityJobs => urgentJobs + emergencyJobs;

  /// Everything that wasn't Urgent or Emergency.
  int get normalJobs => transactions - priorityJobs;

  /// The month split the way the ledger stores it. Derived from the same three
  /// numbers the totals are, so the three series always add back up to the
  /// month above them rather than drifting from it.
  Map<RevenueUrgency, UrgencyTotals> get byUrgency => {
        RevenueUrgency.normal: UrgencyTotals(
          revenue: normalJobs * mockBasePlatformFee,
          transactions: normalJobs,
        ),
        RevenueUrgency.urgent: UrgencyTotals(
          revenue: urgentJobs * (mockBasePlatformFee + mockUrgentFee),
          transactions: urgentJobs,
        ),
        RevenueUrgency.emergency: UrgencyTotals(
          revenue: emergencyJobs * (mockBasePlatformFee + mockEmergencyFee),
          transactions: emergencyJobs,
        ),
      };
}

/// A full calendar year, January first.
///
/// The curve is a young platform growing through the year with two things
/// bent into it that a flat ramp would not show: an April dip, so the charts
/// are exercised by a fall as well as a rise, and a June-September lift where
/// the rainy season puts more breakdowns — and a much heavier Emergency
/// share — on the road.
const List<MockMonthProfile> kMockYearShape = [
  MockMonthProfile(transactions: 214, urgentJobs: 48, emergencyJobs: 12), // Jan
  MockMonthProfile(transactions: 231, urgentJobs: 55, emergencyJobs: 14), // Feb
  MockMonthProfile(transactions: 268, urgentJobs: 63, emergencyJobs: 15), // Mar
  MockMonthProfile(transactions: 252, urgentJobs: 58, emergencyJobs: 13), // Apr
  MockMonthProfile(transactions: 297, urgentJobs: 71, emergencyJobs: 19), // May
  MockMonthProfile(transactions: 341, urgentJobs: 92, emergencyJobs: 28), // Jun
  MockMonthProfile(transactions: 386, urgentJobs: 108, emergencyJobs: 34), // Jul
  MockMonthProfile(transactions: 412, urgentJobs: 121, emergencyJobs: 41), // Aug
  MockMonthProfile(transactions: 398, urgentJobs: 115, emergencyJobs: 37), // Sep
  MockMonthProfile(transactions: 364, urgentJobs: 99, emergencyJobs: 30), // Oct
  MockMonthProfile(transactions: 322, urgentJobs: 78, emergencyJobs: 22), // Nov
  MockMonthProfile(transactions: 356, urgentJobs: 86, emergencyJobs: 26), // Dec
];

/// The mock ledger, as the revenue API would return it.
///
/// Runs January through the month [asOf] falls in, so the Overview's 'year to
/// date' is actually year to date whenever this is run, and prorates that last
/// month by how much of it has passed — the newest bar being short is the
/// month being unfinished, not the platform falling over.
PlatformRevenueSummary buildMockRevenueSummary({
  DateTime? asOf,
  bool includePriorYear = kMockRevenueIncludesPriorYear,
}) {
  final now = asOf ?? DateTime.now();
  final months = <MonthlyIncome>[];

  // The priority totals are accumulated from the very profiles the months are
  // built from, in the same pass. The Income screen states them as a share of
  // the revenue above them, and a separately invented number would let that
  // note contradict the chart it sits under.
  var priorityRevenue = 0.0;
  var priorityJobs = 0;

  void book(int year, int month, MockMonthProfile profile) {
    months.add(MonthlyIncome(
      month: revenueMonthLabels[month - 1],
      year: year,
      revenue: profile.revenue,
      transactions: profile.transactions,
      byUrgency: profile.byUrgency,
    ));
    priorityRevenue += profile.priorityFees;
    priorityJobs += profile.priorityJobs;
  }

  if (includePriorYear) {
    for (var month = 1; month <= 12; month++) {
      book(now.year - 1, month, kMockYearShape[month - 1].scaled(mockPriorYearScale));
    }
  }

  for (var month = 1; month <= now.month; month++) {
    final full = kMockYearShape[month - 1];
    final partial = month == now.month && kMockProratesCurrentMonth;
    book(now.year, month, partial ? full.scaled(_monthElapsed(now)) : full);
  }

  return PlatformRevenueSummary(
    months: List.unmodifiable(months),
    priorityFeeRevenue: priorityRevenue,
    priorityFeeCount: priorityJobs,
  );
}

/// How far into its month [now] is, floored so the newest point stays readable.
double _monthElapsed(DateTime now) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final elapsed = now.day / daysInMonth;
  return elapsed < mockCurrentMonthFloor ? mockCurrentMonthFloor : elapsed;
}
