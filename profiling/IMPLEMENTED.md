# Implemented history performance improvements

The grid now keeps the full logical date extent while materializing only
visible columns plus a small buffer. Scrolling backward automatically swaps
in older cells and retires distant ones; fixed-width spacers keep the
header and rows aligned. No reveal button is required.

The existing full-history query is shared. Records are indexed once by
habit at the query boundary, and each row indexes its own dates. Individual
cells no longer own live queries. An edit performs one scoped fetch,
including pending changes, so repeated taps do not race query delivery.
Every synced duplicate is updated, and latest-record selection breaks
exact timestamp ties deterministically by UUID.

Streak calculation observes each habit's own full history in an independent
view. Unchanged parent inputs do not rerun it during scrolling or another
habit's insertion. State, date, timestamp, membership, hidden-date, and
logical-today changes still participate in observation. The widget's
current-day summary is observed separately and uses the same latest-record
resolution as the cells. Layout date sets and yesterday's key are shared;
header formatters are reused.

The note editor is hosted above virtualized cells and applies its pending
save after dismissal. Goal-name editing now explicitly relinquishes focus
before disabling its text view, avoiding a first-responder loop when a
sheet is presented.

No persistent schema changed. Full-history query/index work still grows
with record count on query refreshes and inserts; this implementation does
not claim constant total CPU cost or database pagination.

## Before/after measurements

Same harness and iPhone 17 Pro / iOS 26.5 Debug simulator as README.md.
Numbers are median process CPU milliseconds in post-change observation
windows, not physical-device tap-to-display latency. All history remains
available; the after column automatically virtualizes its date cells.

| Workload (20 habits, full date extent) | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| First checkoffs, 60 days, normal autosave | 543.95 | 88.15 | 84% |
| Existing-record toggles, 60 days, normal autosave | 255.89 | 39.93 | 84% |
| Existing-record toggles, 60 days, forced save | 957.63 | 93.82 | 90% |
| Existing-record toggles, 180 days, forced save | 4235.75 | 205.25 | 95% |

The profile's `columns` parameter now denotes the logical date extent
provided to the production grid, not the number of instantiated columns.
The benchmark intentionally still uses the unchanged direct model mutation
loop from the baseline; edit-helper correctness is tested separately.

All three profiling methods completed on the new implementation. The run
also exposed a mistaken test bound (it omitted part of bucket rounding),
which was corrected to account for both rounding and prefetching.

Console evidence:
`/var/folders/pv/tgp_ylrd4dbfs93hkd5fp8d80000gn/T/ActionArtifacts/default/RunSomeTests/test-console-log-2026-09-25T00-19-50-04-00.txt`.

See README.md for the baseline methodology, limitations, and reproduction.

## Final validation

- iOS Simulator and macOS builds succeeded. The active destination was
  restored to iPhone 17 Pro (26.5); no macOS UI tests were run.
- The full simulator run reported 71 passes and two failures. The goal
  editing test was corrected to double-tap the interaction overlay's
  coordinates rather than asking XCTest to tap a disabled text field;
  its focused rerun passed. All other UI tests passed, including the new
  60-day scroll/edit/scroll-away/return test, which also checks that fewer
  than 30 date headers are materialized.
- All seven new model/window tests passed. They cover pending inserts,
  duplicate edits, note-only and whitespace edits, widget duplicate
  resolution, viewport bounds, wide containers, and coverage of every
  visible cell across the full scroll extent.
- The remaining failure is the existing
  `DayModelTests/migrationMergesIntentionsIntoDays()` expectation that a
  legacy archived goal remains archived. It reproduced identically on
  an isolated, unmodified `c785ed49` checkout on the same simulator.
  Migration/schema code was not changed in this work.
- Physical-device latency and live CloudKit synchronization were not
  measured. The remaining migration failure means the entire repository
  suite is not green, despite the optimization's checks passing.

Final full-run console: `test-console-log-2026-09-25T00-28-24-04-00.txt`;
goal-editing rerun: `test-console-log-2026-09-25T00-31-18-04-00.txt`;
unmodified baseline migration check:
`test-console-log-2026-09-25T00-32-53-04-00.txt`.
These are under the `RunAllTests` / `RunSomeTests` artifact directories
documented in README.md.
