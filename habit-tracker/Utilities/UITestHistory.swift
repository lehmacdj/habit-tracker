#if DEBUG
import Foundation
import SwiftData

/// Explicitly opt-in, ephemeral UI-test data. Never seed a real store.
enum UITestHistory {
  static func seed(in context: ModelContext) throws {
    var keys = [DayBoundary.dateKey()]
    for _ in 1..<60 {
      keys.append(DayBoundary.yesterdayKey(from: keys.last!))
    }
    for key in keys { context.insert(Day(dateKey: key)) }
    for index in 0..<3 {
      let goal = Goal(name: "History \(index + 1)", sortOrder: index)
      goal.id = UUID(uuidString:
        "00000000-0000-0000-0000-00000000000\(index + 1)")!
      context.insert(goal)
      for key in keys.dropFirst() {
        let record = Completion(dateKey: key, goal: goal)
        if key == keys.last { record.note = "Oldest note" }
        context.insert(record)
      }
    }
    try context.save()
  }
}
#endif
