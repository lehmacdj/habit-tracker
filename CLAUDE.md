# Repository Instructions

## UI Testing

- Run `habit-trackerUITests` only on an iOS Simulator. Before invoking
  Xcode's test actions, confirm that the active run destination is a
  simulator and switch to one if necessary.
- Never run UI tests with `My Mac` or a physical device selected. macOS UI
  automation takes control of the host's keyboard and pointer, preventing
  the user from using the computer while the tests run.

## CloudKit Schema

- Whenever a SwiftData or Core Data schema changes, update the CloudKit
  Development schema before completing the work. Run a signed Debug build
  with `--initialize-cloudkit-schema`, then verify the expected record types
  and fields appear in the Development environment in CloudKit Console.
- Run the schema initializer on `My Mac` by default: build for My Mac, then
  launch `<DerivedData>/Build/Products/Debug/habit-tracker.app` with
  `--initialize-cloudkit-schema` (for example via
  `open -n <app> --args --initialize-cloudkit-schema`). The Mac's iCloud
  account is already signed in, whereas simulators need a sign-in and have
  reported `CKAccountStatusTemporarilyUnavailable`. Running the app on
  My Mac is fine; the UI-testing rule above still forbids running UI tests
  there. Switch back to a simulator destination afterward.
- Confirm success from the unified log, not stdout (redirected stdout is
  buffered and is lost if the app is killed). Success looks like
  `Initialized development schema for iCloud.is.devin.habit-tracker` from
  `log show --last 10m --info --predicate
  'subsystem == "is.devin.habit-tracker" AND category == "CloudKitSchema"'`.
- Do not assume a TestFlight or App Store build can create schema changes;
  those builds use the Production environment. Deploy Development schema
  changes to Production separately before distributing a build that depends
  on them.
