import Foundation
import SwiftData

/// Use a separate context on receipt so a failed watch save cannot roll back
/// an intention the person is currently typing on the phone.
enum WatchEdits {
  static func apply(_ edit: WatchEdit, in context: ModelContext) throws {
    switch edit.value {
    case .mark(let goalID, let state):
      let goals = try context.fetch(FetchDescriptor<Goal>(
        predicate: #Predicate { $0.id == goalID }
      ))
      guard let goal = goals.first, !goal.isArchived else { return }
      let records = try CompletionRecords.fetch(
        goal: goal, dateKey: edit.dateKey, in: context
      )
      // A delayed offline edit must not overwrite a newer phone/cloud edit.
      if let latest = CompletionRecords.latest(records),
        latest.updatedAt >= edit.updatedAt { return }
      if records.isEmpty {
        let record = Completion(dateKey: edit.dateKey, goal: goal)
        record.state = state
        record.updatedAt = edit.updatedAt
        context.insert(record)
      } else {
        for record in records {
          record.state = state
          record.updatedAt = edit.updatedAt
        }
      }
    case .intention(let text):
      let key = edit.dateKey
      let days = try context.fetch(FetchDescriptor<Day>(
        predicate: #Predicate { $0.dateKey == key }
      ))
      let latest = days.compactMap(\.intentionUpdatedAt).max() ?? .distantPast
      guard edit.updatedAt > latest else { return }
      if days.isEmpty {
        let day = Day(dateKey: key, intentionText: text)
        day.intentionUpdatedAt = edit.updatedAt
        context.insert(day)
      } else {
        for day in days {
          day.intentionText = text
          day.intentionUpdatedAt = edit.updatedAt
        }
      }
    }
    try context.save()
  }

  static func today(
    dateKey: String, goals: [Goal], days: [Day], completions: [Completion]
  ) -> WatchToday {
    let day = days.filter { $0.dateKey == dateKey }.max {
      ($0.intentionUpdatedAt ?? .distantPast)
        < ($1.intentionUpdatedAt ?? .distantPast)
    }
    let records = TodayHabits.latestByGoal(
      completions.filter { $0.dateKey == dateKey }
    )
    return WatchToday(
      dateKey: dateKey, intention: day?.intentionText ?? "",
      habits: goals.filter { !$0.isArchived }.sorted {
        if $0.sortOrder == $1.sortOrder {
          return $0.id.uuidString < $1.id.uuidString
        }
        return $0.sortOrder < $1.sortOrder
      }.map {
        WatchToday.Habit(
          id: $0.id, name: $0.name,
          state: records[$0.id]?.state ?? .unmarked
        )
      }
    )
  }

  static func snapshot(in context: ModelContext) throws -> WatchSnapshot {
    let key = DayBoundary.dateKey()
    return WatchSnapshot(today: today(
      dateKey: key,
      goals: try context.fetch(FetchDescriptor<Goal>()),
      days: try context.fetch(FetchDescriptor<Day>(
        predicate: #Predicate { $0.dateKey == key }
      )),
      completions: try context.fetch(FetchDescriptor<Completion>(
        predicate: #Predicate { $0.dateKey == key }
      ))
    ))
  }
}
