import Foundation
import OSLog

enum HabitBackupStore {
  static let appGroupIdentifier =
    "group.is.devin.habit-tracker"
  static let backupInterval: TimeInterval =
    7 * 24 * 60 * 60

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier
      ?? "is.devin.habit-tracker",
    category: "HabitBackup"
  )

  struct BackupFile: Identifiable {
    let url: URL
    let createdAt: Date

    var id: URL { url }
    var filename: String {
      url.lastPathComponent
    }
  }

  static func saveWeeklyIfNeeded(
    _ export: HabitDataExport,
    now: Date = .now,
    directoryURL: URL? = nil
  ) throws {
    if directoryURL == nil && isRunningTests {
      return
    }

    let directory = try directoryURL
      ?? defaultDirectoryURL()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    if let newest = try backups(
      directoryURL: directory
    ).first,
      now.timeIntervalSince(newest.createdAt)
        < backupInterval {
      return
    }

    let destination = directory.appending(
      path: automaticFilename(for: now)
    )
    try export.encodedJSON().write(
      to: destination,
      options: .atomic
    )
    logger.notice(
      "Saved weekly backup \(destination.lastPathComponent)"
    )
  }

  static func backups(
    directoryURL: URL? = nil
  ) throws -> [BackupFile] {
    let directory = try directoryURL
      ?? defaultDirectoryURL()
    guard FileManager.default.fileExists(
      atPath: directory.path
    ) else {
      return []
    }

    return try FileManager.default
      .contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [
          .contentModificationDateKey,
        ],
        options: [.skipsHiddenFiles]
      )
      .filter {
        $0.pathExtension == "json"
          && $0.lastPathComponent.hasPrefix(
            "habit-tracker-weekly-"
          )
      }
      .map { url in
        let values = try url.resourceValues(
          forKeys: [.contentModificationDateKey]
        )
        return BackupFile(
          url: url,
          createdAt:
            values.contentModificationDate ?? .distantPast
        )
      }
      .sorted {
        $0.createdAt > $1.createdAt
      }
  }

  static func automaticFilename(
    for date: Date
  ) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime,
    ]
    let timestamp = formatter
      .string(from: date)
      .replacingOccurrences(of: ":", with: "-")
    return "habit-tracker-weekly-\(timestamp).json"
  }

  private static func defaultDirectoryURL() throws -> URL {
    guard let container = FileManager.default
      .containerURL(
        forSecurityApplicationGroupIdentifier:
          appGroupIdentifier
      )
    else {
      throw CocoaError(
        .fileNoSuchFile,
        userInfo: [
          NSLocalizedDescriptionKey:
            "The Habit Tracker app-group container is unavailable.",
        ]
      )
    }

    return container
      .appending(
        path: "Backups",
        directoryHint: .isDirectory
      )
  }

  private static var isRunningTests: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.arguments.contains("--uitesting")
      || processInfo.environment["XCTestBundlePath"] != nil
      || processInfo.environment[
        "XCTestConfigurationFilePath"
      ] != nil
  }
}
