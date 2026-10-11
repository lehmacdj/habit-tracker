import SwiftUI

@main
struct HabitWatchApp: App {
  @State private var store = WatchTodayStore()

  var body: some Scene {
    WindowGroup {
      WatchRootView(store: store)
    }
    .backgroundTask(.watchConnectivity) {
      await store.receiveBackgroundUpdates()
    }
  }
}

struct WatchRootView: View {
  @Environment(\.scenePhase) private var scenePhase
  let store: WatchTodayStore
  @State private var dateKey = DayBoundary.dateKey()

  var body: some View {
    NavigationStack {
      WatchTodayView(store: store, dateKey: dateKey)
        .id(dateKey)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      if phase == .active {
        dateKey = DayBoundary.dateKey()
        store.refresh()
      }
    }
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(15)) }
        catch { return }
        let key = DayBoundary.dateKey()
        if dateKey != key {
          dateKey = key
          store.refresh()
        }
      }
    }
  }
}
