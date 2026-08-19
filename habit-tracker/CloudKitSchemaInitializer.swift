#if DEBUG
import CoreData
import OSLog
import SwiftData

enum CloudKitSchemaInitializer {
  private nonisolated static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier
      ?? "is.devin.habit-tracker",
    category: "CloudKitSchema"
  )

  @discardableResult
  nonisolated static func initializeIfNeeded(
    modelTypes: [any PersistentModel.Type],
    containerIdentifier: String
  ) -> Bool {
    guard ProcessInfo.processInfo.environment[
      "XCODE_RUNNING_FOR_PREVIEWS"
    ] != "1" else {
      return false
    }

    guard let managedObjectModel =
      NSManagedObjectModel.makeManagedObjectModel(
        for: modelTypes
      )
    else {
      logger.error(
        "Could not generate the CloudKit managed object model"
      )
      return false
    }

    let fingerprint = schemaFingerprint(
      for: managedObjectModel
    )
    let fingerprintKey =
      "cloudKitSchemaFingerprint.\(containerIdentifier)"
    let forceInitialization = ProcessInfo.processInfo
      .arguments
      .contains("--initialize-cloudkit-schema")

    guard forceInitialization
      || UserDefaults.standard.string(
        forKey: fingerprintKey
      ) != fingerprint
    else {
      return true
    }

    let initialized: Bool
    do {
      initialized = try autoreleasepool {
        let storeURL = FileManager.default
          .temporaryDirectory
          .appending(
            path: "CloudKitSchema-\(UUID().uuidString).store"
          )
        let description = NSPersistentStoreDescription(
          url: storeURL
        )
        description.cloudKitContainerOptions =
          NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier
          )
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(
          name: "HabitTracker",
          managedObjectModel: managedObjectModel
        )
        container.persistentStoreDescriptions = [
          description
        ]
        container.loadPersistentStores { _, error in
          if let error {
            logger.error(
              """
              Could not load the CloudKit schema store: \
              \(error.localizedDescription)
              """
            )
          }
        }

        guard let store = container
          .persistentStoreCoordinator
          .persistentStores
          .first
        else {
          return false
        }

        do {
          try container.initializeCloudKitSchema()
          try container
            .persistentStoreCoordinator
            .remove(store)
          try container
            .persistentStoreCoordinator
            .destroyPersistentStore(
              at: storeURL,
              type: .sqlite
            )
          return true
        } catch {
          try? container
            .persistentStoreCoordinator
            .remove(store)
          try? container
            .persistentStoreCoordinator
            .destroyPersistentStore(
              at: storeURL,
              type: .sqlite
            )
          throw error
        }
      }
    } catch {
      logger.error(
        """
        Could not initialize the Development CloudKit schema: \
        \(error.localizedDescription)
        """
      )
      return false
    }

    guard initialized else {
      return false
    }

    UserDefaults.standard.set(
      fingerprint,
      forKey: fingerprintKey
    )
    logger.notice(
      "Initialized development schema for \(containerIdentifier)"
    )
    return true
  }

  private nonisolated static func schemaFingerprint(
    for model: NSManagedObjectModel
  ) -> String {
    model.entityVersionHashesByName
      .sorted { $0.key < $1.key }
      .map { name, hash in
        "\(name)=\(hash.base64EncodedString())"
      }
      .joined(separator: ";")
  }
}
#endif
