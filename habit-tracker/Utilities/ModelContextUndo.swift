import Foundation
import SwiftData

extension ModelContext {
  /// Applies changes the app makes on its own, keeping them off the undo
  /// stack so Undo only reverts what the user did.
  func withoutUndo(_ changes: () -> Void) {
    guard let undoManager else { return changes() }
    // Flush earlier user edits so they keep their own undo registration.
    processPendingChanges()
    undoManager.disableUndoRegistration()
    defer { undoManager.enableUndoRegistration() }
    changes()
    processPendingChanges()
  }
}
