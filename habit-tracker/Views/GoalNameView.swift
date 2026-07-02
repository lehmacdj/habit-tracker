import SwiftUI

struct GoalNameView: View {
  @Bindable var goal: Goal
  @State private var isEditing = false
  @State private var editText = ""
  @FocusState private var isFocused: Bool

  /// When true, immediately enters edit mode (for new goals)
  var startEditing: Bool = false
  var onArchive: (() -> Void)? = nil
  var onDrag: (() -> NSItemProvider)? = nil
  var dragPreview: (() -> AnyView)? = nil

  var body: some View {
    TextField(
      "untitled",
      text: isEditing ? $editText : .constant(goal.name),
      axis: .vertical
    )
    .font(.body)
    .lineLimit(1...2)
    .multilineTextAlignment(.center)
    .focused($isFocused)
    .disabled(!isEditing)
    .foregroundStyle(
      goal.name.isEmpty && !isEditing
        ? .secondary : .primary
    )
    .accessibilityIdentifier("goalNameField")
    .onSubmit { commitRename() }
    .onChange(of: editText) { _, newValue in
      if newValue.contains("\n") {
        editText = newValue.replacingOccurrences(
          of: "\n", with: ""
        )
        commitRename()
      }
    }
    .onChange(of: isFocused) { _, focused in
      if !focused { commitRename() }
    }
    .overlay {
      if !isEditing {
        interactionOverlay
      }
    }
    .frame(minHeight: 48)
    .frame(maxWidth: .infinity)
    .onAppear {
      if startEditing {
        beginEditing()
      }
    }
  }

  @ViewBuilder
  private var interactionOverlay: some View {
    let overlay = Color.clear
      .contentShape(Rectangle())
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

    if let onDrag {
      overlay.onDrag {
        onDrag()
      } preview: {
        if let dragPreview {
          dragPreview()
        } else {
          EmptyView()
        }
      }
    } else {
      overlay
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
