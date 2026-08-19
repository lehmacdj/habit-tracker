import CloudKit
import Combine
import CoreData
import Foundation

struct CloudSyncEventRecord: Codable, Identifiable, Equatable {
  enum Kind: String, Codable, CaseIterable {
    case setup
    case importData
    case exportData

    var title: String {
      switch self {
      case .setup: "Setup"
      case .importData: "Download"
      case .exportData: "Upload"
      }
    }
  }

  let id: UUID
  let kind: Kind
  let startedAt: Date
  let endedAt: Date?
  let succeeded: Bool
  let errorDetails: String?

  var isFinished: Bool { endedAt != nil }
}

final class CloudSyncMonitor: ObservableObject {
  static let shared = CloudSyncMonitor()
  static let containerIdentifier =
    "iCloud.is.devin.habit-tracker"

  enum AccountState: Equatable {
    case checking
    case available
    case unavailable(String)

    var title: String {
      switch self {
      case .checking: "Checking iCloud account…"
      case .available: "iCloud account available"
      case .unavailable(let message): message
      }
    }
  }

  @Published private(set) var accountState: AccountState =
    .checking
  @Published private(set) var events: [CloudSyncEventRecord]

  private let defaults: UserDefaults
  private let container: CKContainer?
  private var notificationObserver: NSObjectProtocol?

  private static let eventsKey = "cloudSync.recentEvents.v1"
  private static let maximumEventCount = 30

  init(
    defaults: UserDefaults = .standard,
    container: CKContainer? = nil,
    observeEvents: Bool = true
  ) {
    self.defaults = defaults
    self.container = container ?? (
      Self.isRunningTests
        ? nil
        : CKContainer(identifier: Self.containerIdentifier)
    )
    events = Self.loadEvents(from: defaults)

    if observeEvents {
      notificationObserver = NotificationCenter.default
        .addObserver(
          forName: NSPersistentCloudKitContainer
            .eventChangedNotification,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          self?.record(notification)
        }
    }
  }

  deinit {
    if let notificationObserver {
      NotificationCenter.default.removeObserver(
        notificationObserver
      )
    }
  }

  var needsAttention: Bool {
    if case .unavailable = accountState {
      return true
    }
    return CloudSyncEventRecord.Kind.allCases.contains {
      kind in
      guard let latest = events.first(
        where: { $0.kind == kind && $0.isFinished }
      ) else {
        return false
      }
      return !latest.succeeded
    }
  }

  var hasActivityInProgress: Bool {
    events.contains { !$0.isFinished }
  }

  func refreshAccountStatus() {
    if Self.isRunningTests {
      accountState = .available
      return
    }

    guard let container else {
      accountState = .unavailable(
        "CloudKit is unavailable in this process"
      )
      return
    }

    accountState = .checking
    container.accountStatus { [weak self] status, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error {
          self.accountState = .unavailable(
            "Could not check iCloud: \(error.localizedDescription)"
          )
          return
        }
        self.accountState = Self.accountState(for: status)
      }
    }
  }

  var diagnosticsText: String {
    var lines = [
      "Habit Tracker Cloud Sync Diagnostics",
      "Generated: \(Date.now.formatted(.iso8601))",
      "App: \(Self.appVersion)",
      "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Model schema: 4.0.0",
      "Account: \(accountState.title)",
      "Container: \(Self.containerIdentifier)",
      "",
    ]

    if events.isEmpty {
      lines.append("No sync events have been observed yet.")
    } else {
      for event in events {
        let result: String
        if !event.isFinished {
          result = "in progress"
        } else if event.succeeded {
          result = "succeeded"
        } else {
          result = "failed"
        }
        lines.append(
          "\(event.kind.title): \(result), "
            + event.startedAt.formatted(.iso8601)
        )
        if let errorDetails = event.errorDetails {
          lines.append(errorDetails)
        }
        lines.append("")
      }
    }
    return lines.joined(separator: "\n")
  }

  private func record(_ notification: Notification) {
    guard let event = notification.userInfo?[
      NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else {
      return
    }

    let record = CloudSyncEventRecord(
      id: event.identifier as UUID,
      kind: Self.kind(for: event.type),
      startedAt: event.startDate,
      endedAt: event.endDate,
      succeeded: event.succeeded,
      errorDetails: event.error.map {
        CloudSyncErrorFormatter.details(for: $0 as NSError)
      }
    )
    events.removeAll { $0.id == record.id }
    events.insert(record, at: 0)
    events = Array(events.prefix(Self.maximumEventCount))
    persistEvents()
  }

  private func persistEvents() {
    guard let data = try? JSONEncoder().encode(events) else {
      return
    }
    defaults.set(data, forKey: Self.eventsKey)
  }

  private static func loadEvents(
    from defaults: UserDefaults
  ) -> [CloudSyncEventRecord] {
    guard let data = defaults.data(forKey: eventsKey),
      let records = try? JSONDecoder().decode(
        [CloudSyncEventRecord].self,
        from: data
      )
    else {
      return []
    }
    return records
  }

  private static func kind(
    for type: NSPersistentCloudKitContainer.EventType
  ) -> CloudSyncEventRecord.Kind {
    switch type {
    case .setup: .setup
    case .import: .importData
    case .export: .exportData
    @unknown default: .setup
    }
  }

  private static func accountState(
    for status: CKAccountStatus
  ) -> AccountState {
    switch status {
    case .available:
      .available
    case .noAccount:
      .unavailable("No iCloud account is signed in")
    case .restricted:
      .unavailable("iCloud access is restricted")
    case .couldNotDetermine:
      .unavailable("Could not determine iCloud account status")
    case .temporarilyUnavailable:
      .unavailable("iCloud is temporarily unavailable")
    @unknown default:
      .unavailable("Unknown iCloud account status")
    }
  }

  private static var isRunningTests: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.arguments.contains("--uitesting")
      || processInfo.environment["XCTestBundlePath"] != nil
      || processInfo.environment[
        "XCTestConfigurationFilePath"
      ] != nil
  }

  private static var appVersion: String {
    let version = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "unknown"
    let build = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "unknown"
    return "\(version) (\(build))"
  }
}

enum CloudSyncErrorFormatter {
  static func details(for error: NSError) -> String {
    var lines: [String] = []
    append(error, to: &lines, indentation: "", depth: 0)
    return lines.joined(separator: "\n")
  }

  private static func append(
    _ error: NSError,
    to lines: inout [String],
    indentation: String,
    depth: Int
  ) {
    guard depth < 5 else { return }
    lines.append(
      "\(indentation)\(error.domain) (\(error.code)): "
        + error.localizedDescription
    )

    if let reason = error.localizedFailureReason,
      reason != error.localizedDescription {
      lines.append("\(indentation)Reason: \(reason)")
    }
    if let suggestion = error.localizedRecoverySuggestion {
      lines.append("\(indentation)Try: \(suggestion)")
    }
    if let retryAfter = error.userInfo[
      CKErrorRetryAfterKey
    ] as? NSNumber {
      lines.append(
        "\(indentation)Retry after: \(retryAfter) seconds"
      )
    }

    let childIndentation = indentation + "  "
    if let underlying = error.userInfo[
      NSUnderlyingErrorKey
    ] as? NSError {
      append(
        underlying,
        to: &lines,
        indentation: childIndentation,
        depth: depth + 1
      )
    }
    if let detailed = error.userInfo[
      NSDetailedErrorsKey
    ] as? NSArray {
      for case let child as NSError in detailed {
        append(
          child,
          to: &lines,
          indentation: childIndentation,
          depth: depth + 1
        )
      }
    }
    for (item, child) in partialErrors(in: error) {
      lines.append("\(childIndentation)Item: \(item)")
      append(
        child,
        to: &lines,
        indentation: childIndentation + "  ",
        depth: depth + 1
      )
    }
  }

  private static func partialErrors(
    in error: NSError
  ) -> [(item: String, error: NSError)] {
    guard let partial = error.userInfo[
      CKPartialErrorsByItemIDKey
    ] as? NSDictionary else {
      return []
    }

    return partial.allKeys.compactMap { key in
      guard let child = partial.object(forKey: key) as? NSError else {
        return nil
      }
      return (String(describing: key), child)
    }.sorted { $0.item < $1.item }
  }
}
