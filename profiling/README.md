# Habit checkoff performance profile — 2026-09-25

Baseline: `c9b4fd87` (`Add an explicit failed state to habit cells`).
This commit contains a profiling harness and proposed improvements, not
production optimizations.

## Result

History-dependent grid work is reproducibly expensive without CloudKit.
Rendering fewer date columns materially reduces it while retaining all
stored history. Prefer a moving rendering window and shared completion
queries over a button that merely reveals another large eager grid.

The first-time checkoff is particularly costly. In this synthetic Debug
simulator workload, median process CPU in each post-insertion observation
window fell from 544 ms to 127 ms when materialized columns fell from 60
to 7 (77% less). The insertion itself took about 0.3 ms. These are local
CPU measurements, **not physical-device tap-to-display latencies**.

## Method and limits

- Xcode 27 beta 6; iPhone 17 Pro simulator running iOS 26.5.
- 20 synthetic goals; 7, 30, 60, or 180 consecutive dates. The user's
  actual goal count and affected device were not supplied.
- In-memory SwiftData store, CloudKit disabled. No user records used.
- The production `HabitGridView` mounted in a 393 x 852 UIKit window.
  A small wrapper supplies live queries for goals, days, and completions.
  The production cells, row layout, and streak code are unchanged.
- Every historical goal/date pair is completed. This exercises long
  streaks; sparse real data can stop the streak scan sooner.
- Two-second warmup after mounting. Twelve operations per fixture.
- Existing-record cases alternate today's first goal between completed
  and unmarked. First-checkoff cases initially omit today's completions,
  then insert today's record for twelve different goals.
- `getrusage(RUSAGE_SELF)` measures total process user + system CPU.
  Each observation window covers mutation, optional explicit save,
  an asynchronous 150 ms wait, and `layoutIfNeeded()` on the host view.
  Busy main-thread work can delay resumption beyond 150 ms.
- Tables report the upper middle sample of twelve, in milliseconds.
  The elapsed window is diagnostic, not a frame completion marker.
  There is no guarantee all asynchronous work has drained at its end.
- The harness omits production widget-summary updates, backup generation,
  disk I/O, and CloudKit synchronization for its synthetic data. The host
  app's ordinary empty test scene is still present. The no-grid control
  measures background process overhead as well as model operations.
- Debug builds and simulator hardware can exaggerate absolute times.
  These experiments establish scaling and promising targets; verify
  improvements in a Release build on the affected device before claiming
  a production latency improvement.
- One eight-second CPU sample overlaps the explicit-save history sweep,
  including setup and updates. It identifies active call paths, not a
  percentage breakdown of a single checkoff. Autosave runs were unsampled.
- The iOS 27 attempt was stopped during startup; no measurements from
  that attempt are included.

## Measurements

### Normal autosave, first checkoffs, 60 stored days

| Rendered date columns | CPU/window | Elapsed window | Insert |
| --- | ---: | ---: | ---: |
| 60 | 543.95 | 532.52 | 0.33 |
| 30 | 274.52 | 267.53 | 0.32 |
| 7 | 127.21 | 152.46 | 0.34 |
| No grid | 1.35 | 155.96 | 0.68 |

### Normal autosave, existing-record toggles, 60 stored days

| Rendered date columns | CPU/window | Elapsed window | Mutation |
| --- | ---: | ---: | ---: |
| 60 | 255.89 | 240.73 | 0.02 |
| 30 | 145.77 | 154.77 | 0.04 |
| 7 | 67.12 | 154.07 | 0.04 |
| No grid | 0.69 | 157.08 | 0.03 |

### Explicit save after every existing-record toggle

The app's cell action does not call `save()` itself. This sweep deliberately
forces save notifications and is a separate stress case, not the normal
tap path. The synchronous save is small compared with subsequent work.

| Stored days | Rendered columns | CPU/window | Elapsed window | Save |
| --- | --- | ---: | ---: | ---: |
| 7 | 7 | 209.52 | 199.99 | 1.46 |
| 30 | 30 | 602.23 | 573.52 | 3.67 |
| 60 | 60 | 957.63 | 929.74 | 4.95 |
| 60 | 30 | 511.03 | 524.32 | 3.07 |
| 60 | 7 | 300.17 | 365.08 | 1.52 |
| 180 | 180 | 4235.75 | 4141.00 | 13.76 |
| 180 | 30 | 846.82 | 825.87 | 3.97 |

The same 30-column limit becomes more expensive with 180 stored days.
Limiting the rendered history alone does not bound the full-history work.

## Findings in the production code

1. **Each cell owns a live query.** `CompletionCellView.swift:6,36`
   defines a relationship/date predicate and an `updatedAt` sort for every
   goal/date pair. The CPU sample includes this main-thread path:
   `CompletionCellView.body -> cellContent -> fillColor -> state ->
   completion -> completions -> SwiftData -> NSManagedObjectContext.fetch`.
   This is observed fetch work, not merely the presence of query objects.
2. **Rows eagerly construct horizontal history.**
   `HabitGridView.swift:68,70,236,248` uses a two-axis scroll view, a
   `LazyVStack` for rows, and a regular `HStack`/`ForEach` for all date
   columns. Vertical laziness does not make those columns horizontally
   lazy. Twenty materialized rows across 60 dates can own 1,200 cell
   queries, despite only a handful of columns being onscreen.
3. **Every row filters all completions to compute its streak.**
   `HabitGridView.swift:349` reads each completion's goal and ID while
   filtering. `HabitStreak.currentQualifyingLength` then rebuilds the
   latest-entry dictionary and walks backward through dates. Both the
   filtering and date walking appear in the sampled main-thread stacks.
   Repeating the global filter for every row costs roughly
   goals × total-completions model accesses per grid reevaluation.
4. **Repeated derived layout work.** `HabitGridView.swift:33,48,252,275`
   reconstructs date sets and sorted layout arrays through computed
   properties, including from individual cell construction. Yesterday's
   date is reparsed repeatedly by `allowsTapToComplete`. Header formatting
   creates two new formatters per header evaluation. These are secondary
   cleanup targets; their individual savings were not isolated here.
5. **Additional production-only work needs measurement later.**
   `ContentView.swift:172` scans each goal's historical relationship to
   count today's completions. A changed count writes the widget summary
   and requests a timeline reload. Backup export construction happens on
   appearance/activation, before the weekly rate-limit check; it is a
   launch/resume concern, not part of every cell action. Neither subsystem
   explains away the expensive isolated grid measurements above.

## Proposed implementation

### 1. Share completion data and isolate row updates

Replace per-cell `@Query` with shared query results indexed by goal ID and
date key. Build that index in one pass, not one full filter per cell or
row. Pass the appropriate records to each cell. Keep all duplicates in
the index: the current view displays the newest `updatedAt` record and
writes a new state or note to every duplicate. Preserve these semantics.

Give each row a dedicated view and goal-specific completion snapshot.
Compute its streak from that row's entries, and update only the affected
row when completion values change. Rebuild or invalidate derived data for
CloudKit imports, inserts/deletes, `updatedAt`, mark and note changes,
goal reassignment, hidden dates, and the logical-day boundary. A cache
keyed only by array count or IDs would miss ordinary edits.

Compute date layout, the visible-date set, and yesterday's key once per
relevant date-list/today change. Derive the widget count from the same
resolved current-day data instead of walking historical relationships.

Start with a single authoritative full-history query if that keeps
correctness simple. Window-filtering that query is a later refinement;
streaks still require older history or a separately maintained summary.
The shared-query improvement has not been benchmarked in a prototype yet.

### 2. Seamless backward scrolling with bounded materialization

Keep the lightweight ordered date-key list and full logical scroll width.
Materialize only the visible columns plus a prefetch margin; use exact
width leading/trailing spacers for the rest. Every row and the pinned
header use the same window. The fixed 48-point day widths make this
tractable; account separately for the 160-point Goals column, left fill,
and future dates.

Use scroll geometry to advance the shared column range in coarse chunks,
not to update state for every scroll pixel. Starting near today can render
at most the latest 30 dates, then shift the window as the user scrolls
back. Retire distant cell views as the window moves. All known dates
remain reachable with ordinary scrolling, without a reveal button or
ever-growing collection of live cell queries.

Because spacers preserve logical widths, loading older cell views need
not move the date beneath the user's finger. If metadata itself is later
loaded in 30-day pages, preserve a date ID and its pixel offset when
prepending a page. Prefer keyset date bounds over numeric fetch offsets
when dates can arrive through sync.

This is a rendering window, not `Day.isHidden`, deletion, or a streak
cutoff. Keep full-history streak rules and selection behavior. Ensure
an open note editor survives window eviction, for example by hosting it
above the virtualized cells. Keep headers aligned, context-menu neighbor
checks based on all known visible dates, and overscroll-to-create-tomorrow
based on full logical width. Do not assume nesting `LazyHStack` inside the
existing two-axis scroll container automatically provides correct sizing
and virtualization; verify the materialized cell count and scroll behavior.

### 3. Verification before shipping

- Repeat this harness at 60 and 180 days with a constant viewport.
  Query/view work should track the viewport and changed goal, not total
  historical cell count. Recheck both inserts and existing-record edits.
- Measure Release first-checkoff latency and animation hitches on the
  affected device, including autosave and CloudKit imports.
- Exercise backward/forward scrolling and confirm the date under the
  finger does not jump; test pinned headers, goal reordering, old notes,
  insertion/deletion/restoration of dates, and the tomorrow gesture.
- Verify duplicate completion resolution, skipped/failed/unmarked states,
  long streaks across hidden dates, widget count, and midnight/4 AM changes.
- Check that remote updates to offscreen dates appear when scrolled into
  view and update the relevant streak before becoming visible.

These changes can be implemented without a persisted schema change.

## Reproduction and artifacts

`HabitGridProfileTests.swift` is intentionally outside the test target so
ordinary tests do not acquire a several-minute profiling sweep. Copy it
temporarily to `habit-trackerTests/HabitGridProfileTests.swift`, then use
Xcode MCP with the `habit-tracker` scheme and an **iOS Simulator** destination.
Run these individually using `RunSomeTests`:

- `HabitGridProfileTests/testHistoryScaling()`
- `HabitGridProfileTests/testAutosaveScaling()`
- `HabitGridProfileTests/testFirstCompletionScaling()`

All three completed successfully on iOS 26.5, one test per run. Remove the
temporary test-target copy afterward. Tests are observations with a final
model-state assertion, not timing regression thresholds or UI correctness
tests. No production source, schema, or user data was changed.

Original console logs are under:

`/var/folders/pv/tgp_ylrd4dbfs93hkd5fp8d80000gn/T/ActionArtifacts/default/RunSomeTests/`

- `test-console-log-2026-09-25T00-02-53-04-00.txt` — explicit-save sweep
- `test-console-log-2026-09-25T00-06-00-04-00.txt` — autosave toggles
- `test-console-log-2026-09-25T00-07-25-04-00.txt` — first checkoffs

Matching `.xcresult` bundles are in the same directory. The uncommitted
CPU sample is `tmp/habit-profile/baseline-sample.txt` (PID 45185, eight
seconds at 1 ms, captured 00:04:14). Temporary logs can be purged; the
tables and harness above preserve the reproducible findings.

Apple's supporting guidance:

- [Creating performant scrollable stacks](https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks)
- [Demystify SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/)
- [ScrollGeometry](https://developer.apple.com/documentation/swiftui/scrollgeometry)
