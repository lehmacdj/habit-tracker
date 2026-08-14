import Foundation
import SwiftData

/// Archiving hides a goal from the grid without discarding its
/// completions, so restoring one only has to make it visible
/// again and give it a slot in the goal ordering.
enum GoalArchive {
  @MainActor
  static func archive(
    _ goal: Goal,
    in modelContext: ModelContext
  ) throws {
    try modelContext.transaction {
      goal.archivedAt = Date()
    }
  }

  /// Restores an archived goal to the bottom of the grid.
  /// The active goals are renumbered so the restored goal can
  /// never collide with an existing sort order.
  @MainActor
  static func restore(
    _ goal: Goal,
    activeGoals: [Goal],
    in modelContext: ModelContext
  ) throws {
    try modelContext.transaction {
      let ordered = activeGoals
        .filter { $0.id != goal.id }
        .sorted { $0.sortOrder < $1.sortOrder }

      for (index, active) in ordered.enumerated() {
        active.sortOrder = index
      }

      goal.sortOrder = ordered.count
      goal.archivedAt = nil
      goal.isDeleted = false
    }
  }

  /// Archived goals ordered for display, with named goals
  /// sorted alphabetically ahead of untitled ones.
  @MainActor
  static func displayOrder(archived goals: [Goal]) -> [Goal] {
    goals.sorted { lhs, rhs in
      if lhs.name.isEmpty != rhs.name.isEmpty {
        return rhs.name.isEmpty
      }
      if lhs.name.isEmpty {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        == .orderedAscending
    }
  }
}
