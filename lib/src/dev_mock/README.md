# `dev_mock/` — fake revenue data for UI testing

Invented numbers, kept in one folder so they can be deleted in one step.

The Admin **Overview** and **Income → Revenue** screens read a ledger that is
empty until the mobile app reports a real payment, so there is normally nothing
to look at: no line, no bars, no rings. This folder fills that
ledger with a plausible year of platform revenue **without touching a single
production file** — the screens, the charts and `PlatformRevenueApi` are all
unmodified.

## What it feeds

| Screen | What it fills |
| --- | --- |
| Overview | `<Month> Revenue` stat tile, the `Revenue — <year>` line chart (hover callouts, axis, month labels) |
| Income | `YTD Revenue` and `Transactions` tiles, the priority-fee note, the **Yearly Revenue** bar chart, the **Transactions by urgency** rings |

## How it is wired

One call, from `lib/main.dart`:

```dart
import 'src/dev_mock/dev_mock.dart';
...
installDevMocks();
```

`installDevMocks()` calls `ConsoleBackend.configure(revenue: MockRevenueService())`
— the same seam the real HTTP client will use. Nothing else in the console
knows the data is fake. The moderation queue, the moderator roster and the
audit trail keep their real local services.

The dependency only ever points one way: `dev_mock/` imports production code,
production code never imports `dev_mock/`.

## Knobs

All in `mock_revenue_data.dart`, except the first:

- `kDevMocksEnabled` (`dev_mock.dart`) — `false` runs the console against the
  real, empty ledger without deleting anything.
- `kMockRevenueIncludesPriorYear` — `true` adds last calendar year, which is
  what makes the Income screen's `+19% vs 2025` chip appear. Off by default:
  the Overview titles its card from the *first* month it is handed and plots
  them all, so two years read as a 2025-labelled 21-point curve there.
- `kMockProratesCurrentMonth` — `false` draws the month in progress at full
  height instead of cutting it to the part of the month that has passed.
- `kMockYearShape` — the twelve-month curve itself (transactions, Urgent jobs,
  Emergency jobs per month). Revenue is derived from these, never typed in.
- `mockBasePlatformFee` / `mockUrgentFee` / `mockEmergencyFee` — ₱25 booked per
  completed payment, plus the ₱50 / ₱100 priority surcharges.
- `mockCurrentMonthFloor` — the month in progress is prorated by how much of it
  has passed; this stops a run early in a month from drawing a near-zero point.

The data is deterministic — no RNG — so a chart that changes between two frames
changed because of the widget, not the data.

## Removing it

1. Delete `lib/src/dev_mock/`.
2. Delete the `dev_mock.dart` import and the `installDevMocks();` line in
   `lib/main.dart`.

That is the whole footprint.
