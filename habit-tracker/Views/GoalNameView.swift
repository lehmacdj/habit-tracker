import SwiftUI

struct GoalNameView: View {
  @Bindable var goal: Goal
  @State private var isEditing = false
  @State private var editText = ""
  @FocusState private var isFocused: Bool

  /// When true, immediately enters edit mode (for new goals)
  var startEditing: Bool = false
  var onArchive: (() -> Void)? = nil

  var body: some View {
    Group {
      if isEditing {
        TextField("goal name", text: $editText)
          .font(.body)
          .multilineTextAlignment(.center)
          .focused($isFocused)
          .onSubmit { commitRename() }
          .onChange(of: isFocused) { _, focused in
            if !focused { commitRename() }
          }
      } else {
        Text(goal.name.isEmpty ? "untitled" : goal.name)
          .font(.body)
          .foregroundStyle(
            goal.name.isEmpty ? .secondary : .primary
          )
          .onTapGesture(count: 2) {
            beginEditing()
          }
          .contextMenu {
            Button(role: .destructive) {
              onArchive?()
            } label: {
              Label(
                "Archive Goal",
                systemImage: "archivebox"
              )
            }
          }
      }
    }
    .frame(height: 56)
    .frame(maxWidth: .infinity)
    .onAppear {
      if startEditing {
        beginEditing()
      }
    }
  }

  private func beginEditing() {
    editText = goal.name
    isEditing = true
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 0.1
    ) {
      isFocused = true
    }
  }

  private func commitRename() {
    let trimmed = editText.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if !trimmed.isEmpty && trimmed != goal.name {
      if !goal.name.isEmpty {
        goal.rename(to: trimmed)
      } else {
        goal.name = trimmed
      }
    }
    isEditing = false
  }
}
