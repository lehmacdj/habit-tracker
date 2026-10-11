#if os(iOS)
import SwiftUI

struct WatchSummaryUpdater: View {
  @Environment(\.scenePhase) private var scenePhase
  let dateKey: String
  let goals: [Goal]
  let days: [Day]
  let completions: [Completion]

  var body: some View {
    let today = WatchEdits.today(
      dateKey: dateKey, goals: goals, days: days, completions: completions
    )
    Color.clear
      .frame(width: 0, height: 0)
      .onChange(of: today, initial: true) { _, _ in
        PhoneWatchSync.shared.publish()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { PhoneWatchSync.shared.publish() }
      }
  }
}
#endif
