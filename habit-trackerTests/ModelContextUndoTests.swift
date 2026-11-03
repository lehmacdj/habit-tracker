import Foundation
import SwiftData
import Testing
@testable import habit_tracker

@MainActor
struct ModelContextUndoTests {
  @Test func undoRevertsUserEditsButNotHousekeeping() throws {
    let container = try ModelContainer(
      for: Goal.self, Completion.self, Day.self,
      configurations: ModelConfiguration(
        isStoredInMemoryOnly: true, cloudKitDatabase: .none
      )
    )
    let context = container.mainContext
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    context.undoManager = undoManager
    let day = Day(dateKey: "2026-11-03")
    context.withoutUndo { context.insert(day) }
    #expect(!undoManager.canUndo)

    undoManager.beginUndoGrouping()
    day.intentionText = "Read"
    context.processPendingChanges()
    undoManager.endUndoGrouping()
    undoManager.undo()
    #expect(day.intentionText == "")
    #expect(try context.fetch(FetchDescriptor<Day>()).count == 1)
    undoManager.redo()
    #expect(day.intentionText == "Read")
  }
}
