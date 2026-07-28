import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct habit_trackerApp: App {
  private static let iCloudContainerIdentifier =
    "iCloud.is.devin.habit-tracker"

  private static let modelTypes: [any PersistentModel.Type] = [
    Goal.self,
    Completion.self,
    Intention.self,
    Day.self,
  ]

  init() {
    #if os(iOS)
    if Self.isTesting {
      UIView.setAnimationsEnabled(false)
    }
    #endif
  }

  var sharedModelContainer: ModelContainer = {
    let schema = Schema(Self.modelTypes)

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: Self.isTesting,
      cloudKitDatabase: Self.isTesting
        ? .none
        : .private(iCloudContainerIdentifier)
    )

    do {
      #if DEBUG
      if !Self.isTesting {
        CloudKitSchemaInitializer.initializeIfNeeded(
          modelTypes: Self.modelTypes,
          configuration: config,
          containerIdentifier: iCloudContainerIdentifier
        )
      }
      #endif

      return try ModelContainer(
        for: schema,
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
