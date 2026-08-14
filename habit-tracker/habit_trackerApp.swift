import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct habit_trackerApp: App {
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
  }

  var sharedModelContainer: ModelContainer = {
    let schema = Schema(
      versionedSchema: HabitSchemaV4.self
    )

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: Self.isTesting,
      cloudKitDatabase: Self.isTesting
        ? .none
        : .private(iCloudContainerIdentifier)
    )

    do {
      if !Self.isTesting {
        try MigrationStoreBackup.createIfNeeded(
          storeURL: config.url,
          modelTypes: Self.modelTypes
        )
      }

      #if DEBUG
      if !Self.isTesting {
        CloudKitSchemaInitializer.initializeIfNeeded(
          modelTypes: Self.modelTypes,
          containerIdentifier: iCloudContainerIdentifier
        )
      }
      #endif

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
