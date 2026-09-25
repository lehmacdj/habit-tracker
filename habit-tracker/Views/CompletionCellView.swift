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
          apply(.completed)
        } label: {
          cellContent
        }
        .buttonStyle(.plain)
      } else {
        cellContent
      }
    }
    .contextMenu {
      menuButton(
        for: .completed,
        title: "Complete",
        systemImage: "checkmark"
      )
      menuButton(
        for: .skipped,
        title: "Skip",
        systemImage: "minus.circle"
      )
      menuButton(
        for: .failed,
        title: "Fail",
        systemImage: "xmark"
      )
      Divider()
      Button {
        onEditNote()
      } label: {
        Label(
          hasNote ? "Edit Note" : "Add Note",
          systemImage: hasNote
            ? "note.text"
            : "note.text.badge.plus"
        )
      }
    }
    .accessibilityIdentifier("completion-\(goal.id)-\(dateKey)")
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

  /// Selecting the state a cell is already in clears it, so
  /// the menu doubles as the way to undo a mark.
  @ViewBuilder
  private func menuButton(
    for target: CompletionState,
    title: String,
    systemImage: String
  ) -> some View {
    let isActive = state == target
    Button {
      apply(target)
    } label: {
      Label(
        isActive ? "Clear \(title)" : title,
        systemImage: isActive
          ? "arrow.uturn.backward"
          : systemImage
      )
    }
  }

  private var cellContent: some View {
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
      try CompletionRecords.toggle(
        target, goal: goal, dateKey: dateKey, in: modelContext
      )
    } catch {
      editError = "The habit could not be updated. "
        + error.localizedDescription
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
