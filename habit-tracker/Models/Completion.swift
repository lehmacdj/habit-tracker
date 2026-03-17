import Foundation
import SwiftData

@Model
final class Completion {
  var id: UUID = UUID()
  var dateKey: String = ""
  var isCompleted: Bool = true
  var updatedAt: Date = Date()

  var goal: Goal?

  init(dateKey: String, goal: Goal) {
    self.id = UUID()
    self.dateKey = dateKey
    self.isCompleted = true
    self.updatedAt = Date()
    self.goal = goal
  }
}
