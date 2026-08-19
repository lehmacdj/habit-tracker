# Repository Instructions

## CloudKit Schema

- Whenever a SwiftData or Core Data schema changes, update the CloudKit
  Development schema before completing the work. Run a signed Debug build
  with `--initialize-cloudkit-schema`, then verify the expected record types
  and fields appear in the Development environment in CloudKit Console.
- Do not assume a TestFlight or App Store build can create schema changes;
  those builds use the Production environment. Deploy Development schema
  changes to Production separately before distributing a build that depends
  on them.
