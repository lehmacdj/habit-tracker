import SwiftUI
import SwiftData

@main
struct habit_trackerApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Goal.self,
      Completion.self,
      Intention.self,
      Day.self,
    ])

    let isTesting = ProcessInfo.processInfo.arguments
      .contains("--uitesting")

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isTesting,
      cloudKitDatabase: isTesting ? .none : .automatic
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

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
