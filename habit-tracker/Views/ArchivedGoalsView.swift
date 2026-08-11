import SwiftData
import SwiftUI

struct ArchivedGoalsView: View {
  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Goal.sortOrder)
  private var allGoals: [Goal]

  private var archivedGoals: [Goal] {
    GoalArchive.displayOrder(
      archived: allGoals.filter(\.isDeleted)
    )
  }

  private var activeGoals: [Goal] {
    allGoals.filter { !$0.isDeleted }
  }

  var body: some View {
    NavigationStack {
      Form {
        if archivedGoals.isEmpty {
          Section {
            Text(
              """
              Nothing is archived. Archiving a goal from the \
              grid keeps its history here so you can bring it \
              back later.
              """
            )
            .foregroundStyle(.secondary)
          }
        } else {
          Section {
            ForEach(archivedGoals) { goal in
              archivedGoalRow(goal)
            }
          } footer: {
            Text(
              """
              Restored goals return to the bottom of the grid \
              with their completions intact.
              """
            )
          }
        }
      }
      .navigationTitle("Archived Goals")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 460, minHeight: 420)
    #endif
  }

  @ViewBuilder
  private func archivedGoalRow(_ goal: Goal) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(goal.name.isEmpty ? "untitled" : goal.name)
          .foregroundStyle(
            goal.name.isEmpty ? .secondary : .primary
          )
        Text(historySummary(for: goal))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Button {
        restore(goal)
      } label: {
        Label(
          "Restore",
          systemImage: "arrow.uturn.backward"
        )
        .labelStyle(.titleAndIcon)
      }
      .buttonStyle(.borderless)
      .accessibilityIdentifier("restoreGoalButton")
      .accessibilityLabel(
        "Restore \(goal.name.isEmpty ? "untitled" : goal.name)"
      )
    }
  }

  private func historySummary(for goal: Goal) -> String {
    let completedKeys = (goal.completions ?? [])
      .filter(\.isCompleted)
      .map(\.dateKey)

    guard let lastKey = completedKeys.max(),
      let lastDate = DayBoundary.displayDate(for: lastKey)
    else {
      return "No completions"
    }

    let count = completedKeys.count
    let label = count == 1 ? "completion" : "completions"
    let formatted = lastDate.formatted(
      date: .abbreviated,
      time: .omitted
    )
    return "\(count) \(label) · last on \(formatted)"
  }

  private func restore(_ goal: Goal) {
    withAnimation {
      GoalArchive.restore(goal, activeGoals: activeGoals)
    }
  }
}

#Preview {
  let container = try! ModelContainer(
    for: Goal.self, Completion.self, Day.self,
    configurations: ModelConfiguration(
      isStoredInMemoryOnly: true
    )
  )
  let ctx = container.mainContext
  let active = Goal(name: "Exercise", sortOrder: 0)
  let archived = Goal(name: "Read", sortOrder: 1)
  archived.isDeleted = true
  let untitled = Goal(name: "", sortOrder: 2)
  untitled.isDeleted = true
  ctx.insert(active)
  ctx.insert(archived)
  ctx.insert(untitled)
  ctx.insert(
    Completion(dateKey: DayBoundary.dateKey(), goal: archived)
  )
  return ArchivedGoalsView()
    .modelContainer(container)
}
