import Foundation
import SwiftData

/// Retain every synced duplicate without observing marks in the grid.
enum CompletionRecords {
  static func byGoal(_ records: [Completion]) -> [UUID: [Completion]] {
    var result: [UUID: [Completion]] = [:]
    for record in records {
      guard let goalID = record.goal?.id else { continue }
      result[goalID, default: []].append(record)
    }
    return result
  }

  static func latest(_ records: [Completion]) -> Completion? {
    records.max {
      if $0.updatedAt == $1.updatedAt {
        return $0.id.uuidString < $1.id.uuidString
      }
      return $0.updatedAt < $1.updatedAt
    }
  }

  /// Fetch on an edit, not per cell during rendering. Pending inserts
  /// let rapid taps see edits before the shared query delivers results.
  static func fetch(
    goal: Goal, dateKey: String, in context: ModelContext
  ) throws -> [Completion] {
    let goalID = goal.id
    return try context.fetch(FetchDescriptor<Completion>(
      predicate: #Predicate {
        $0.goal?.id == goalID && $0.dateKey == dateKey
      }
    ))
  }

  static func toggle(
    _ target: CompletionState, goal: Goal, dateKey: String,
    in context: ModelContext
  ) throws {
    let records = try fetch(goal: goal, dateKey: dateKey, in: context)
    let state = latest(records)?.state ?? .unmarked
    let newState: CompletionState = state == target ? .unmarked : target
    if records.isEmpty {
      guard newState != .unmarked else { return }
      let record = Completion(dateKey: dateKey, goal: goal)
      record.state = newState
      context.insert(record)
    } else {
      let now = Date()
      for record in records {
        record.state = newState
        record.updatedAt = now
      }
    }
  }

  static func saveNote(
    _ text: String, goal: Goal, dateKey: String,
    in context: ModelContext
  ) throws {
    let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
      .isEmpty ? "" : text
    let records = try fetch(goal: goal, dateKey: dateKey, in: context)
    if records.isEmpty {
      guard !note.isEmpty else { return }
      let record = Completion(dateKey: dateKey, goal: goal)
      record.state = .unmarked
      record.note = note
      context.insert(record)
    } else {
      let now = Date()
      for record in records {
        record.note = note
        record.updatedAt = now
      }
    }
  }
}
