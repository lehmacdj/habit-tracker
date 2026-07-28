import CoreData
import CryptoKit
import Foundation
import SwiftData

enum MigrationStoreBackup {
  struct Manifest: Codable {
    let createdAt: Date
    let sourceStorePath: String
    let targetSchemaFingerprint: String
    let files: [String]
  }

  @discardableResult
  static func createIfNeeded(
    storeURL: URL,
    modelTypes: [any PersistentModel.Type],
    backupRootURL: URL? = nil,
    now: Date = .now
  ) throws -> URL? {
    let fileManager = FileManager.default
    guard fileManager.fileExists(
      atPath: storeURL.path
    ) else {
      return nil
    }

    let fingerprint = try targetFingerprint(
      modelTypes: modelTypes
    )
    let fingerprintID = SHA256.hash(
      data: Data(fingerprint.utf8)
    )
    .map { String(format: "%02x", $0) }
    .joined()
    .prefix(16)
    let root = try backupRootURL
      ?? defaultBackupRootURL()
    let destination = root.appending(
      path: "before-schema-\(fingerprintID)",
      directoryHint: .isDirectory
    )

    if fileManager.fileExists(
      atPath: destination.path
    ) {
      return destination
    }

    try fileManager.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    let pending = root.appending(
      path: ".pending-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    try fileManager.createDirectory(
      at: pending,
      withIntermediateDirectories: true
    )

    do {
      let sourceURLs = [
        storeURL,
        URL(filePath: storeURL.path + "-wal"),
        URL(filePath: storeURL.path + "-shm"),
      ].filter {
        fileManager.fileExists(atPath: $0.path)
      }

      for sourceURL in sourceURLs {
        try fileManager.copyItem(
          at: sourceURL,
          to: pending.appending(
            path: sourceURL.lastPathComponent
          )
        )
      }

      let manifest = Manifest(
        createdAt: now,
        sourceStorePath: storeURL.path,
        targetSchemaFingerprint: fingerprint,
        files: sourceURLs.map(\.lastPathComponent)
      )
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [
        .prettyPrinted,
        .sortedKeys,
      ]
      try encoder.encode(manifest).write(
        to: pending.appending(path: "manifest.json"),
        options: .atomic
      )
      try fileManager.moveItem(
        at: pending,
        to: destination
      )
      return destination
    } catch {
      try? fileManager.removeItem(at: pending)
      throw error
    }
  }

  private static func targetFingerprint(
    modelTypes: [any PersistentModel.Type]
  ) throws -> String {
    guard let model =
      NSManagedObjectModel.makeManagedObjectModel(
        for: modelTypes
      )
    else {
      throw CocoaError(
        .coderInvalidValue,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Could not generate the target data model.",
        ]
      )
    }

    return model.entityVersionHashesByName
      .sorted { $0.key < $1.key }
      .map { name, hash in
        "\(name)=\(hash.base64EncodedString())"
      }
      .joined(separator: ";")
  }

  private static func defaultBackupRootURL() throws -> URL {
    guard let container = FileManager.default
      .containerURL(
        forSecurityApplicationGroupIdentifier:
          HabitBackupStore.appGroupIdentifier
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
      .appending(
        path: "StoreSnapshots",
        directoryHint: .isDirectory
      )
  }
}
