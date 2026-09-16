import 'package:on_go_console_backend/console_backend.dart';

import 'mock_revenue_service.dart';

export 'mock_revenue_data.dart';
export 'mock_revenue_service.dart';

/// FAKE DATA — UI TESTING ONLY. See `lib/src/dev_mock/README.md`.
///
/// Everything invented for the sake of looking at a screen lives under this
/// folder, and this is the only door into it. Production code never imports
/// `dev_mock/`; `dev_mock/` imports production. That direction is what makes
/// the whole thing removable — delete the folder and the two lines in
/// `main.dart` that call [installDevMocks], and nothing else has to change.

/// The master switch. Flip to `false` to run the console against the real,
/// empty local ledger without deleting anything.
const bool kDevMocksEnabled = true;

/// Swaps the mock revenue ledger in, before `runApp`.
///
/// Goes through [ConsoleBackend.configure], the same seam the HTTP client will
/// use one day, so no screen and no service knows this happened. Every
/// contract not named here keeps its real local implementation: the queue, the
/// moderator roster and the audit trail are untouched.
void installDevMocks() {
  if (!kDevMocksEnabled) return;
  ConsoleBackend.configure(revenue: MockRevenueService());
}
