import Foundation

/// How a goal was resolved on a particular day.
enum CompletionState: String, Codable, CaseIterable, Sendable {
  /// Nothing was recorded, or a previous mark was cleared.
  case unmarked
  /// The goal was done.
  case completed
  /// The goal was intentionally skipped. Skipped days are
  /// not completions, but they also do not break a streak.
  case skipped
  /// The goal was explicitly not done. Like an unmarked day
  /// it counts against a streak, but it records a decision
  /// rather than an absence.
  case failed

  /// Shared by phone and watch, so the same mark always has the same symbol.
  var symbol: String {
    switch self {
    case .unmarked: "circle"
    case .completed: "checkmark.circle.fill"
    case .skipped: "minus.circle.fill"
    case .failed: "xmark.circle.fill"
    }
  }

  var actionSymbol: String {
    switch self {
    case .unmarked: "arrow.uturn.backward"
    case .completed: "checkmark"
    case .skipped: "minus.circle"
    case .failed: "xmark"
    }
  }
}
