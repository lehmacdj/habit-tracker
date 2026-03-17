import Foundation
import SwiftData

struct NameHistoryEntry: Codable {
  var oldName: String
  var changedAt: Date
}

@Model
final class Goal {
  var id: UUID = UUID()
  var name: String = ""
  var sortOrder: Int = 0
  var createdAt: Date = Date()
  var isDeleted: Bool = false
  var nameHistoryJSON: String = "[]"

  @Relationship(deleteRule: .cascade, inverse: \Completion.goal)
  var completions: [Completion]? = []

  init(name: String = "", sortOrder: Int = 0) {
    self.id = UUID()
    self.name = name
    self.sortOrder = sortOrder
    self.createdAt = Date()
  }

  var nameHistory: [NameHistoryEntry] {
    get {
      guard let data = nameHistoryJSON.data(using: .utf8)
      else { return [] }
      return (try? JSONDecoder().decode(
        [NameHistoryEntry].self, from: data
      )) ?? []
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        nameHistoryJSON = String(data: data, encoding: .utf8)
          ?? "[]"
      }
    }
  }

  func rename(to newName: String) {
    var history = nameHistory
    history.append(NameHistoryEntry(
      oldName: name,
      changedAt: Date()
    ))
    nameHistory = history
    name = newName
  }
}
