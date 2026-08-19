import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct habit_trackerApp: App {
  // Start listening before the model container is created so the
  // initial CloudKit setup event is visible in the diagnostics UI.
  private let cloudSyncMonitor = CloudSyncMonitor.shared

  private static let iCloudContainerIdentifier =
    "iCloud.is.devin.habit-tracker"

  private static let modelTypes =
    HabitSchemaV4.models

  init() {
    #if os(iOS)
    if Self.isTesting {
      UIView.setAnimationsEnabled(false)
    }
    #endif

    #if DEBUG
    if !Self.isTesting {
      DispatchQueue.global(qos: .userInitiated).async {
        let initialized = CloudKitSchemaInitializer.initializeIfNeeded(
          modelTypes: Self.modelTypes,
          containerIdentifier: Self.iCloudContainerIdentifier
        )
        if Self.isSchemaInitializationRun {
          print(
            initialized
              ? "CloudKit Development schema initialized"
              : "CloudKit Development schema initialization failed"
          )
        }
      }
    }
    #endif
  }

  var sharedModelContainer: ModelContainer = {
    let schema = Schema(
      versionedSchema: HabitSchemaV4.self
    )
    let usesEphemeralStore = Self.isTesting
      || Self.isSchemaInitializationRun

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: usesEphemeralStore,
      cloudKitDatabase: usesEphemeralStore
        ? .none
        : .private(iCloudContainerIdentifier)
    )

    do {
      if !usesEphemeralStore {
        try MigrationStoreBackup.createIfNeeded(
          storeURL: config.url,
          modelTypes: Self.modelTypes
        )
      }

      return try ModelContainer(
        for: schema,
        migrationPlan: HabitSchemaMigrationPlan.self,
        configurations: [config]
      )
    } catch {
      fatalError(
        "Could not create ModelContainer: \(error)"
      )
    }
  }()

  private static var isTesting: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.arguments.contains("--uitesting")
      || processInfo.environment["XCTestBundlePath"] != nil
      || processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  private static var isSchemaInitializationRun: Bool {
    ProcessInfo.processInfo.arguments.contains(
      "--initialize-cloudkit-schema"
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }
    #if os(macOS)
    .defaultSize(width: 800, height: 600)
    #endif
    .modelContainer(sharedModelContainer)
  }
}
