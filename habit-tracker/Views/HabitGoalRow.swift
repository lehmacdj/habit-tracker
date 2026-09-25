import SwiftUI

struct HabitGoalRow: View {
  let goal: Goal
  let completions: [Completion]
  let layout: DayColumnLayout
  let pastRange: Range<Int>
  let futureRange: Range<Int>
  let fillWidth: CGFloat
  let hiddenDateKeys: Set<String>
  let todayKey: String
  let startEditing: Bool
  let onArchive: () -> Void
  let onEditNote: (String) -> Void

  var body: some View {
    // Only dates are read here. State/note observation stays in the
    // corresponding cell and streak title, not in every row's parent.
    let byDate = Dictionary(grouping: completions, by: \.dateKey)
    HStack(spacing: 0) {
      if fillWidth > 0 {
        Color.clear.frame(width: fillWidth, height: 48)
      }
      WindowedDayColumns(keys: layout.pastDateKeys, range: pastRange) {
        cell(for: $0, records: byDate[$0] ?? [])
      }
      HabitStreakTitle(
        goal: goal, completions: completions,
        hiddenDateKeys: hiddenDateKeys, todayKey: todayKey,
        startEditing: startEditing, onArchive: onArchive
      )
      .equatable()
      .frame(width: GridViewport.goalWidth)
      WindowedDayColumns(
        keys: layout.currentAndFutureDateKeys, range: futureRange
      ) {
        cell(for: $0, records: byDate[$0] ?? [])
      }
    }
    .frame(minHeight: GridViewport.cellWidth)
  }

  private func cell(for key: String, records: [Completion]) -> some View {
    CompletionCellView(
      completions: records, goal: goal, dateKey: key,
      allowsTapToComplete: layout.allowsTapToComplete(for: key),
      onEditNote: { onEditNote(key) }
    )
  }
}

/// Scrolling and another goal's insertion do not recompute this streak.
/// SwiftData observation still invalidates this body when these records'
/// values change; equality only suppresses unchanged parent inputs.
private struct HabitStreakTitle: View, Equatable {
  let goal: Goal
  let completions: [Completion]
  let hiddenDateKeys: Set<String>
  let todayKey: String
  let startEditing: Bool
  let onArchive: () -> Void

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.goal == rhs.goal && lhs.completions == rhs.completions
      && lhs.hiddenDateKeys == rhs.hiddenDateKeys
      && lhs.todayKey == rhs.todayKey
      && lhs.startEditing == rhs.startEditing
  }

  var body: some View {
    let entries = Dictionary(grouping: completions, by: \.dateKey)
      .values.compactMap { records -> HabitStreak.Entry? in
        guard let record = CompletionRecords.latest(records) else {
          return nil
        }
        return HabitStreak.Entry(
          dateKey: record.dateKey, state: record.state,
          updatedAt: record.updatedAt
        )
      }
    GoalNameView(
      goal: goal,
      streakLength: HabitStreak.currentQualifyingLength(
        entries: entries, hiddenDateKeys: hiddenDateKeys,
        effectiveTodayKey: todayKey
      ),
      startEditing: startEditing, onArchive: onArchive,
      dragValue: goal.id.uuidString,
      dragPreview: {
        AnyView(Text(goal.name.isEmpty ? "untitled" : goal.name)
          .font(.body)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .shadow(radius: 4))
      }
    )
  }
}
