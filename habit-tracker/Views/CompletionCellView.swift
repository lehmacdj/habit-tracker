import SwiftUI
import SwiftData

struct CompletionCellView: View {
  @Environment(\.modelContext) private var modelContext
  let completions: [Completion]

  let goal: Goal
  let dateKey: String
  /// Today and yesterday complete with a single tap. Every
  /// other cell only changes through the context menu so old
  /// and future days aren't marked by accident.
  let allowsTapToComplete: Bool

  static let skippedYellowOpacity = 0.35
  static let failedRedOpacity = 0.35

  let onEditNote: () -> Void
  var isChecklist = false
  var onMarked: ((CompletionState, CompletionState) -> Void)? = nil
  @State private var editError: String?

  private var completion: Completion? {
    CompletionRecords.latest(completions)
  }

  private var state: CompletionState {
    completion?.state ?? .unmarked
  }

  private var hasNote: Bool {
    completion?.hasNote ?? false
  }

  var body: some View {
    Group {
      if allowsTapToComplete {
        Button {
          apply(isChecklist && state != .unmarked ? state : .completed)
        } label: {
          cellContent
        }
        .buttonStyle(.plain)
      } else {
        cellContent
      }
    }
    .contextMenu {
      CompletionStatusMenu(
        state: state, hasNote: hasNote,
        onApply: apply, onEditNote: onEditNote
      )
    }
    .accessibilityIdentifier("completion-\(goal.id)-\(dateKey)")
    .accessibilityLabel(goal.name.isEmpty ? "Untitled habit" : goal.name)
    .accessibilityValue(state.rawValue + (hasNote ? ", has note" : ""))
    .alert("Could Not Update Habit", isPresented: Binding(
      get: { editError != nil },
      set: { if !$0 { editError = nil } }
    )) {
      Button("OK") { editError = nil }
    } message: {
      Text(editError ?? "Please try again.")
    }
    #if os(iOS)
    .sensoryFeedback(.impact, trigger: state)
    #endif
  }

  @ViewBuilder
  private var cellContent: some View {
    if isChecklist {
      Image(systemName: statusSymbol)
        .font(.title2)
        .foregroundStyle(statusColor)
        .frame(width: 48, height: 48)
        .background(fillColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
          if hasNote {
            Image(systemName: "note.text")
              .font(.system(size: 9))
              .padding(3)
          }
        }
        .contentShape(Rectangle())
    } else {
      Rectangle()
        .fill(fillColor)
        .frame(width: 48, height: 48)
        .overlay(
          Rectangle()
            .strokeBorder(
              Color.secondary.opacity(0.25),
              lineWidth: 0.5
            )
        )
        .overlay(alignment: .topTrailing) {
          if hasNote {
            Image(systemName: "note.text")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
              .padding(4)
              .accessibilityHidden(true)
          }
        }
        .contentShape(Rectangle())
        .accessibilityValue(hasNote ? "Has note" : "")
    }
  }

  private var statusSymbol: String {
    switch state {
    case .unmarked: "circle"
    case .completed: "checkmark.circle.fill"
    case .skipped: "minus.circle.fill"
    case .failed: "xmark.circle.fill"
    }
  }

  private var statusColor: Color {
    switch state {
    case .unmarked: .secondary
    case .completed: .green
    case .skipped: .yellow
    case .failed: .red
    }
  }

  private var fillColor: Color {
    switch state {
    case .completed:
      Color.green.opacity(
        HabitStreak.completedGreenOpacity
      )
    case .skipped:
      Color.yellow.opacity(Self.skippedYellowOpacity)
    case .failed:
      Color.red.opacity(Self.failedRedOpacity)
    case .unmarked:
      Color.secondary.opacity(0.08)
    }
  }

  private func apply(_ target: CompletionState) {
    do {
      let change = try CompletionRecords.toggle(
        target, goal: goal, dateKey: dateKey, in: modelContext
      )
      if isChecklist { try modelContext.save() }
      onMarked?(change.previous, change.current)
    } catch {
      editError = "The habit could not be updated. "
        + error.localizedDescription
    }
  }
}

/// Both screens use the same menu and status control.
struct CompletionStatusMenu: View {
  let state: CompletionState
  let hasNote: Bool
  let onApply: (CompletionState) -> Void
  let onEditNote: () -> Void

  var body: some View {
    menuButton(.completed, title: "Complete", symbol: "checkmark")
    menuButton(.skipped, title: "Skip", symbol: "minus.circle")
    menuButton(.failed, title: "Fail", symbol: "xmark")
    Divider()
    Button(action: onEditNote) {
      Label(
        hasNote ? "Edit Note" : "Add Note",
        systemImage: hasNote ? "note.text" : "note.text.badge.plus"
      )
    }
  }

  private func menuButton(
    _ target: CompletionState, title: String, symbol: String
  ) -> some View {
    Button { onApply(target) } label: {
      Label(
        state == target ? "Clear \(title)" : title,
        systemImage: state == target ? "arrow.uturn.backward" : symbol
      )
    }
  }
}

struct CompletionNoteEditor: View {
  @Environment(\.dismiss) private var dismiss

  let goalName: String
  let dateKey: String
  let onSave: (String) -> Void

  @State private var text: String
  @FocusState private var isFocused: Bool

  init(
    goalName: String,
    dateKey: String,
    initialText: String,
    onSave: @escaping (String) -> Void
  ) {
    self.goalName = goalName
    self.dateKey = dateKey
    self.onSave = onSave
    _text = State(initialValue: initialText)
  }

  private var subtitle: String {
    let name = goalName.isEmpty ? "untitled" : goalName
    guard let date = DayBoundary.displayDate(for: dateKey)
    else { return name }
    return "\(name) · "
      + date.formatted(date: .abbreviated, time: .omitted)
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 8) {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        TextEditor(text: $text)
          .focused($isFocused)
          .scrollContentBackground(.hidden)
          .padding(4)
          .background(
            Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8)
          )
          .accessibilityIdentifier("completionNoteEditor")
      }
      .padding()
      .navigationTitle("Note")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isFocused = false
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(text)
            isFocused = false
            dismiss()
          }
          .accessibilityIdentifier("saveCompletionNoteButton")
        }
      }
      .task {
        // Context-menu dismissal can steal focus from a sheet that is
        // still presenting. Request it after that transition completes.
        do {
          try await Task.sleep(for: .milliseconds(300))
        } catch {
          return
        }
        isFocused = true
      }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    #endif
  }
}
