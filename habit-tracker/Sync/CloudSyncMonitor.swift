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

  /// userInfo keys already covered by the error's localized text.
  private static let localizedKeys: Set<String> = [
    NSLocalizedDescriptionKey,
    NSLocalizedFailureReasonErrorKey,
    NSLocalizedRecoverySuggestionErrorKey,
  ]

  private static let keyLabels: [String: String] = [
    NSUnderlyingErrorKey: "Underlying error",
    NSMultipleUnderlyingErrorsKey: "Underlying errors",
    NSDetailedErrorsKey: "Detailed errors",
    NSDebugDescriptionErrorKey: "Debug description",
    NSFilePathErrorKey: "File path",
    NSURLErrorKey: "URL",
    NSURLErrorFailingURLStringErrorKey: "Failing URL",
    NSValidationObjectErrorKey: "Validation object",
    NSValidationKeyErrorKey: "Validation key",
    NSValidationValueErrorKey: "Validation value",
    NSAffectedObjectsErrorKey: "Affected objects",
    NSAffectedStoresErrorKey: "Affected stores",
    NSPersistentStoreSaveConflictsErrorKey: "Save conflicts",
    CKErrorRetryAfterKey: "Retry after (seconds)",
    CKPartialErrorsByItemIDKey: "Failed items",
    CKRecordChangedErrorServerRecordKey: "Server record",
    CKRecordChangedErrorClientRecordKey: "Client record",
    CKRecordChangedErrorAncestorRecordKey: "Ancestor record",
  ]

  private typealias NestedErrors = (
    label: String,
    items: [(item: String?, error: NSError)]
  )

  private static func append(
    _ error: NSError,
    to lines: inout [String],
    indentation: String,
    depth: Int
  ) {
    guard depth < 5 else {
      lines.append("\(indentation)… (nested too deeply)")
      return
    }
    lines.append(
      "\(indentation)\(title(for: error)): "
        + error.localizedDescription
    )
    if let summary = ErrorCodeCatalog.entry(for: error)?.summary {
      lines.append("\(indentation)About: \(summary)")
    }

    if let reason = error.localizedFailureReason,
      !error.localizedDescription.contains(reason) {
      lines.append("\(indentation)Reason: \(reason)")
    }
    if let suggestion = error.localizedRecoverySuggestion {
      lines.append("\(indentation)Try: \(suggestion)")
    }

    // Render scalar values first, then any errors nested under any
    // key, so every domain gets the same treatment.
    var nested: [NestedErrors] = []
    for key in error.userInfo.keys.sorted()
    where !localizedKeys.contains(key) {
      guard let value = error.userInfo[key] else { continue }
      let label = keyLabels[key] ?? key
      if let items = nestedErrors(in: value) {
        nested.append((label, items))
        continue
      }
      if let collection = value as? NSArray, collection.count == 0 {
        continue
      }
      if let collection = value as? NSDictionary, collection.count == 0 {
        continue
      }
      let text = truncated(describe(value))
      guard !text.isEmpty, text != error.localizedDescription else {
        continue
      }
      lines.append("\(indentation)\(label): \(text)")
    }

    let childIndentation = indentation + "  "
    for (label, items) in nested {
      if items.count == 1 && items[0].item == nil {
        lines.append("\(indentation)\(label):")
      } else {
        lines.append(
          "\(indentation)\(label): \(items.count) "
            + "(\(codeSummary(for: items.map(\.error))))"
        )
      }
      for (item, child) in items {
        var itemIndentation = childIndentation
        if let item {
          lines.append("\(childIndentation)Item: \(item)")
          itemIndentation += "  "
        }
        append(
          child,
          to: &lines,
          indentation: itemIndentation,
          depth: depth + 1
        )
      }
    }
  }

  /// Errors held directly, in an array, or in a dictionary keyed by the
  /// affected item (e.g. CloudKit partial failures).
  private static func nestedErrors(
    in value: Any
  ) -> [(item: String?, error: NSError)]? {
    switch value {
    case let error as NSError:
      return [(nil, error)]
    case let array as NSArray where array.count > 0:
      let errors = array.compactMap { $0 as? NSError }
      guard errors.count == array.count else { return nil }
      return errors.map { (nil, $0) }
    case let dictionary as NSDictionary where dictionary.count > 0:
      var items: [(item: String?, error: NSError)] = []
      for key in dictionary.allKeys {
        guard let error = dictionary.object(forKey: key) as? NSError
        else { return nil }
        items.append((describe(key), error))
      }
      return items.sorted { ($0.item ?? "") < ($1.item ?? "") }
    default:
      return nil
    }
  }

  private static func title(for error: NSError) -> String {
    let title = "\(error.domain) (\(error.code))"
    guard let name = codeName(for: error) else { return title }
    return "\(title) \(name)"
  }

  private static func codeSummary(for errors: [NSError]) -> String {
    var counts: [String: Int] = [:]
    for error in errors {
      let name = codeName(for: error)
        ?? "\(error.domain) \(error.code)"
      counts[name, default: 0] += 1
    }
    return counts
      .sorted { ($1.value, $0.key) < ($0.value, $1.key) }
      .map { "\($0.key) ×\($0.value)" }
      .joined(separator: ", ")
  }

  private static func codeName(for error: NSError) -> String? {
    ErrorCodeCatalog.entry(for: error)?.name
  }

  /// Keeps values such as managed objects or record dumps from
  /// overwhelming the rest of the report.
  private static func truncated(
    _ text: String,
    limit: Int = 300
  ) -> String {
    guard text.count > limit else { return text }
    return text.prefix(limit) + "… (\(text.count - limit) more characters)"
  }

  private static func describe(_ item: Any) -> String {
    switch item {
    case let recordID as CKRecord.ID:
      "\(recordID.recordName) (zone: \(recordID.zoneID.zoneName))"
    case let zoneID as CKRecordZone.ID:
      "zone \(zoneID.zoneName) (owner: \(zoneID.ownerName))"
    case let record as CKRecord:
      "\(record.recordType) \(describe(record.recordID))"
    case let string as String:
      string
    default:
      String(describing: item)
    }
  }
}
