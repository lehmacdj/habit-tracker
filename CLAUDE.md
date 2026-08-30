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
- Do not assume a TestFlight or App Store build can create schema changes;
  those builds use the Production environment. Deploy Development schema
  changes to Production separately before distributing a build that depends
  on them.
