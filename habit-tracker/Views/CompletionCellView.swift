import SwiftUI
import SwiftData

struct CompletionCellView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var completions: [Completion]

  let goalId: UUID
  let goal: Goal
  let dateKey: String
  let cellAge: CellAge

  enum CellAge {
    case current    // today (or effective today)
    case yesterday  // yesterday (single tap)
    case older      // requires long press
  }

  init(goal: Goal, dateKey: String, cellAge: CellAge) {
    self.goal = goal
    self.goalId = goal.id
    self.dateKey = dateKey
    self.cellAge = cellAge
    let gid = goal.id
    let dk = dateKey
    _completions = Query(
      filter: #Predicate<Completion> {
        $0.goal?.id == gid && $0.dateKey == dk
      }
    )
  }

  private var completion: Completion? {
    completions.first
  }

  private var isCompleted: Bool {
    completion?.isCompleted ?? false
  }

  var body: some View {
    Group {
      switch cellAge {
      case .current, .yesterday:
        Button(action: toggle) {
          cellContent
        }
        .buttonStyle(.plain)
      case .older:
        cellContent
          .onLongPressGesture(minimumDuration: 0.5) {
            toggle()
          }
      }
    }
    #if os(iOS)
    .sensoryFeedback(.impact, trigger: isCompleted)
    #endif
  }

  private var cellContent: some View {
    Rectangle()
      .fill(
        isCompleted
          ? Color.green.opacity(0.35)
          : Color(.systemGray6)
      )
      .frame(width: 48, height: 48)
      .overlay(
        Rectangle()
          .strokeBorder(
            Color(.systemGray4),
            lineWidth: 0.5
          )
      )
      .contentShape(Rectangle())
  }

  private func toggle() {
    if let existing = completion {
      existing.isCompleted.toggle()
      existing.updatedAt = Date()
    } else {
      let c = Completion(dateKey: dateKey, goal: goal)
      modelContext.insert(c)
    }
  }
}
