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
      .contentShape(Rectangle())
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
}
