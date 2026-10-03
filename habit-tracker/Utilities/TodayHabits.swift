import Foundation

enum TodayHabits {
  static func intentionIsSatisfied(_ days: [Day]) -> Bool {
    let latest = days.max {
      ($0.intentionUpdatedAt ?? .distantPast)
        < ($1.intentionUpdatedAt ?? .distantPast)
    }
    return !(latest?.intentionText ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Call with today's records only. Duplicates resolve just like the grid.
  static func latestByGoal(_ records: [Completion]) -> [UUID: Completion] {
    CompletionRecords.byGoal(records).compactMapValues {
      CompletionRecords.latest($0)
    }
  }

  /// Stable across reordering and note edits; a changed mark invalidates it.
  static func signature(
    dateKey: String, goals: [Goal], records: [UUID: Completion]
  ) -> String {
    dateKey + ":" + goals.map {
      $0.id.uuidString + "=" + (records[$0.id]?.state ?? .unmarked).rawValue
    }.sorted().joined(separator: ",")
  }

  /// No celebration for an empty list or when the final mark is Fail.
  static func shouldCelebrate(
    states: [CompletionState], finalMark: CompletionState
  ) -> Bool {
    !states.isEmpty && !states.contains(.unmarked)
      && (finalMark == .completed || finalMark == .skipped)
  }
}
