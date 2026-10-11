# Watch app

Run the shared `HabitWatch` scheme on a paired Apple Watch simulator or device.
The iOS app embeds the watch app; macOS builds exclude it. The watch target
supports watchOS 26 and later and requires the companion iPhone app.

The watch supports Today, intention editing, Complete, Skip, Fail, clearing a
mark, and Show finished. Each habit is a full-row button. Swipe left for Skip
and Fail. Habit management and notes stay in the iPhone app. Status and action
symbols are shared through `CompletionState`.

## Sync

The iPhone remains the SwiftData/iCloud owner. `PhoneWatchSync` sends a Today
snapshot through WatchConnectivity's application context and live messages.
Live messages are sent whenever the watch is reachable, independently of
background-context availability.
The watch stores that snapshot and its pending edits atomically on disk.
It can track habits offline after receiving its first snapshot.

Edits carry an absolute value, logical date, UUID, and timestamp. They are sent
through both live messages and queued user-info transfers. The phone acknowledges
an edit only after saving it (or determining that a newer edit supersedes it).
Repeated delivery is idempotent; delayed edits cannot replace newer changes.
Cleared marks remain as unmarked records so an older delayed completion cannot
resurrect them. Existing completion notes are preserved.

The watch overlays unacknowledged edits on incoming snapshots and removes them
only after a receipt. Older snapshots never replace newer ones. The shared
4 a.m. day boundary resets the displayed day even offline; yesterday's queued
edits retain their original date. SwiftUI's watch-connectivity background task
keeps the watch alive while queued updates arrive.

No SwiftData or CloudKit schema change is required.

## Verification

`WatchSyncTests` covers duplicate/out-of-order deliveries, clearing marks,
archived habits, note preservation, duplicate day records, offline day rollover,
and the persisted wire/cache formats. Run phone unit/UI tests only on an iOS
Simulator, per the repository instructions.

For watch UI checks without a paired phone, launch a Debug build with
`--watch-demo`. This uses an in-memory fixture and does not alter the normal
watch cache or send messages. Omit that argument for normal persistence/sync.

Apple does not support `transferUserInfo` in Simulator. Before release, use a
real paired iPhone/Watch to check background delivery, leaving/re-entering range,
app termination/relaunch with pending edits, and dictation. Also check live
changes in both directions and confirm the waiting count clears after a receipt.

Reference: https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)
