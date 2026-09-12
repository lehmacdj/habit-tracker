import Foundation
import SwiftData

/// How a goal was resolved on a particular day.
enum CompletionState: String, Codable, CaseIterable, Sendable {
  /// Nothing was recorded, or a previous mark was cleared.
  case unmarked
  /// The goal was done.
  case completed
  /// The goal was intentionally skipped. Skipped days are
  /// not completions, but they also do not break a streak.
  case skipped
}

@Model
final class Completion {
  var id: UUID = UUID()
  var dateKey: String = ""

  /// Legacy mirror of `state`, kept in sync by its setter so
  /// that builds predating `stateRawValue` keep reading the
  /// right value out of CloudKit. Remove once every client
  /// has been updated.
  var isCompleted: Bool = true

  /// Source of truth for `state`. Empty means the record was
  /// written before skipping existed, so `state` falls back
  /// to `isCompleted`. That fallback is also what makes
  /// records synced from an older client read correctly.
  var stateRawValue: String = ""

  var updatedAt: Date = Date()

  var goal: Goal?

  init(dateKey: String, goal: Goal) {
    self.id = UUID()
    self.dateKey = dateKey
    self.updatedAt = Date()
    self.goal = goal
    self.isCompleted = true
    self.stateRawValue = CompletionState.completed.rawValue
  }

  /// The only sanctioned way to read or write a cell's mark.
  /// Assigning through it keeps the legacy flag consistent
  /// and makes "completed and skipped" unrepresentable.
  var state: CompletionState {
    get {
      CompletionState(rawValue: stateRawValue)
        ?? (isCompleted ? .completed : .unmarked)
    }
    set {
      stateRawValue = newValue.rawValue
      isCompleted = newValue == .completed
    }
  }
}
