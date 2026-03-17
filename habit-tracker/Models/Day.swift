import Foundation
import SwiftData

@Model
final class Day {
  var id: UUID = UUID()
  var dateKey: String = ""
  var isHidden: Bool = false
  var createdAt: Date = Date()

  init(dateKey: String) {
    self.id = UUID()
    self.dateKey = dateKey
    self.createdAt = Date()
  }
}
