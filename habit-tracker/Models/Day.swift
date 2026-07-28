import Foundation
import SwiftData

@Model
final class Day {
  var id: UUID = UUID()
  var dateKey: String = ""
  var isHidden: Bool = false
  var createdAt: Date = Date()
  var intentionText: String = ""
  var intentionUpdatedAt: Date?

  init(
    dateKey: String,
    intentionText: String = ""
  ) {
    self.id = UUID()
    self.dateKey = dateKey
    self.createdAt = Date()
    self.intentionText = intentionText
    self.intentionUpdatedAt =
      intentionText.isEmpty ? nil : Date()
  }
}
