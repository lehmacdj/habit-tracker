import Foundation

enum GoalOrdering {
  /// Move only the dragged habit, including across hidden finished habits.
  /// A nil destination means the end of the full order.
  static func move(
    _ sourceID: UUID, before destinationID: UUID?, in goals: [Goal]
  ) {
    guard sourceID != destinationID,
      let source = goals.first(where: { $0.id == sourceID })
    else { return }
    var reordered = goals.filter { $0.id != sourceID }
    let index: Int
    if let destinationID {
      guard let destination = reordered.firstIndex(where: {
        $0.id == destinationID
      }) else { return }
      index = destination
    } else {
      index = reordered.count
    }
    reordered.insert(source, at: index)
    for (index, goal) in reordered.enumerated() {
      goal.sortOrder = index
    }
  }
}
