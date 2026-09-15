import SwiftUI
import SwiftData

struct CompletionCellView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var completions: [Completion]

  let goalId: UUID
  let goal: Goal
  let dateKey: String
  /// Today and yesterday complete with a single tap. Every
  /// other cell only changes through the context menu so old
  /// and future days aren't marked by accident.
  let allowsTapToComplete: Bool

  static let skippedYellowOpacity = 0.35

  @State private var isEditingNote = false
  /// Held until the editor has finished dismissing. Writing
  /// the model mid-dismissal re-renders the cell hosting the
  /// sheet while the text view is still resigning focus.
  @State private var pendingNote: String?

  init(
    goal: Goal,
    dateKey: String,
    allowsTapToComplete: Bool
  ) {
    self.goal = goal
    self.goalId = goal.id
    self.dateKey = dateKey
    self.allowsTapToComplete = allowsTapToComplete
    let gid = goal.id
    let dk = dateKey
    _completions = Query(
      filter: #Predicate<Completion> {
        $0.goal?.id == gid && $0.dateKey == dk
      },
      sort: \Completion.updatedAt,
      order: .reverse
    )
  }

  private var completion: Completion? {
    completions.first
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
      Divider()
      Button {
        isEditingNote = true
      } label: {
        Label(
          hasNote ? "Edit Note" : "Add Note",
          systemImage: hasNote
            ? "note.text"
            : "note.text.badge.plus"
        )
      }
    }
    .sheet(isPresented: $isEditingNote, onDismiss: {
      guard let note = pendingNote else { return }
      pendingNote = nil
      saveNote(note)
    }) {
      CompletionNoteEditor(
        goalName: goal.name,
        dateKey: dateKey,
        initialText: completion?.note ?? "",
        onSave: { pendingNote = $0 }
      )
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
    case .unmarked:
      Color.secondary.opacity(0.08)
    }
  }

  private func apply(_ target: CompletionState) {
    let newState: CompletionState =
      state == target ? .unmarked : target

    guard !completions.isEmpty else {
      guard newState != .unmarked else { return }
      let completion = Completion(
        dateKey: dateKey,
        goal: goal
      )
      completion.state = newState
      modelContext.insert(completion)
      return
    }

    let now = Date()
    for completion in completions {
      completion.state = newState
      completion.updatedAt = now
    }
  }

  /// Notes can be added to a cell that has no mark yet, in
  /// which case the note lives on an unmarked record.
  private func saveNote(_ text: String) {
    let note = text.trimmingCharacters(
      in: .whitespacesAndNewlines
    ).isEmpty ? "" : text

    guard !completions.isEmpty else {
      guard !note.isEmpty else { return }
      let completion = Completion(
        dateKey: dateKey,
        goal: goal
      )
      completion.state = .unmarked
      completion.note = note
      modelContext.insert(completion)
      return
    }

    let now = Date()
    for completion in completions {
      completion.note = note
      completion.updatedAt = now
    }
  }
}

private struct CompletionNoteEditor: View {
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
      .onAppear {
        isFocused = true
      }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    #endif
  }
}
