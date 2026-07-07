import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct habit_trackerApp: App {
  private static let iCloudContainerIdentifier =
    "iCloud.is.devin.habit-tracker"

  init() {
    #if os(iOS)
    if Self.isTesting {
      UIView.setAnimationsEnabled(false)
    }
    #endif
  }

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Goal.self,
      Completion.self,
      Intention.self,
      Day.self,
    ])

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: Self.isTesting,
      cloudKitDatabase: Self.isTesting
        ? .none
        : .private(iCloudContainerIdentifier)
    )

    do {
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
    }
    .modelContainer(sharedModelContainer)
  }
}
