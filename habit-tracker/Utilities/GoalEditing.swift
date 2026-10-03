import SwiftData

enum GoalEditing {
  static func add(to goals: [Goal], in context: ModelContext) -> Goal {
    let goal = Goal(name: "", sortOrder: (goals.map(\.sortOrder).max() ?? -1) + 1)
    context.insert(goal)
    return goal
  }
}
