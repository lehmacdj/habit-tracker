import CoreTransferable
import UniformTypeIdentifiers

/// A habit drag must not be treated as text dropped into its name field.
struct HabitDragItem: Codable, Transferable {
  let id: String

  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .habitIdentifier)
  }
}

private extension UTType {
  static let habitIdentifier = UTType(
    exportedAs: "is.devin.habit-tracker.habit-identifier"
  )
}
