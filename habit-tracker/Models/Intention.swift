import Foundation
import SwiftData

@Model
final class Intention {
  var id: UUID = UUID()
  var dateKey: String = ""
  var text: String = ""
  var updatedAt: Date = Date()

  init(dateKey: String, text: String = "") {
    self.id = UUID()
    self.dateKey = dateKey
    self.text = text
    self.updatedAt = Date()
  }
}
