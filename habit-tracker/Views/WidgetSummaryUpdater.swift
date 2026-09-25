import SwiftUI

/// Observe today's values independently of the grid and its history.
struct WidgetSummaryUpdater: View {
  @Environment(\.scenePhase) private var scenePhase
  let dateKey: String
  let goals: [Goal]
  let days: [Day]
  let completions: [Completion]

  struct Summary: Equatable {
    let dateKey: String
    let intention: String?
    let count: Int

    func save() {
      HabitWidgetSummaryStore.save(
        dateKey: dateKey, todayIntention: intention, completedCount: count
      )
    }
  }

  var summary: Summary {
    let day = days.max {
      ($0.intentionUpdatedAt ?? .distantPast)
        < ($1.intentionUpdatedAt ?? .distantPast)
    }
    let text = day?.intentionText.trimmingCharacters(
      in: .whitespacesAndNewlines
    ) ?? ""
    let records = CompletionRecords.byGoal(completions)
    let count = goals.filter {
      CompletionRecords.latest(records[$0.id] ?? [])?.state == .completed
    }.count
    return Summary(
      dateKey: dateKey, intention: text.isEmpty ? nil : text, count: count
    )
  }

  var body: some View {
    let value = summary
    Color.clear
      .frame(width: 0, height: 0)
      .onChange(of: value, initial: true) { _, newValue in
        newValue.save()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { value.save() }
      }
  }
}
